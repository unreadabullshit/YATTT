const std = @import("std");

// file imports
const utils = @import("utils.zig");
const main = @import("main.zig");
const input = @import("input.zig");

// aliases(for convenience)
const io = std.io;
const os = std.posix;
const mem = std.mem;
const fs = std.fs;
const termios = os.termios;

// types
const Terminal = @This();
const EasyWriter = io.Writer(fs.File, os.WriteError, fs.File.write);
const TerminalLoopConfig = struct { output: *const fn (EasyBufferedWriter.Writer, TerminalSize) void, input: ?*const fn (?input.InputType) void };

// pub types
pub const TerminalSize = struct { width: usize, height: usize };
pub const EasyBufferedWriter = io.BufferedWriter(4096, EasyWriter);

// variables
var original_term: termios = undefined;
var new_term: termios = undefined;
var terminal_size: TerminalSize = undefined;
var allocator: mem.Allocator = undefined;
var buffered_writer: EasyBufferedWriter = undefined;
var loop_config: TerminalLoopConfig = undefined;

pub fn init(someAllocator: mem.Allocator) !void {
    // setting globals
    buffered_writer = io.bufferedWriter(main.in.writer());
    allocator = someAllocator;
    original_term = try os.tcgetattr(main.in.handle);
    new_term = original_term;
    terminal_size = getTerminalSize();

    // handle terminal width change
    os.sigaction(os.SIG.WINCH, &os.Sigaction{
        .handler = .{ .handler = handleSigWinch },
        .mask = os.empty_sigset,
        .flags = 0,
    }, null);

    // setting up termios
    new_term.lflag.ECHO = false;
    new_term.lflag.ICANON = false;
    new_term.lflag.ISIG = false;
    new_term.lflag.IEXTEN = false;

    new_term.iflag.IXON = false;
    new_term.iflag.ICRNL = false;
    new_term.iflag.BRKINT = false;
    new_term.iflag.INPCK = false;
    new_term.iflag.ISTRIP = false;

    new_term.oflag.OPOST = false;

    new_term.cflag.CSIZE = .CS8;

    new_term.cc[@intFromEnum(os.system.V.TIME)] = 0; // No timeout
    new_term.cc[@intFromEnum(os.system.V.MIN)] = 1; // Wait for at least one character

    try os.tcsetattr(main.in.handle, .FLUSH, new_term);

    const w = buffered_writer.writer();

    // applying terminal magic spells
    try w.writeAll("\x1b[?25l"); // Hide cursor
    try w.writeAll("\x1b[s"); // Save cursor position
    try w.writeAll("\x1b[?47h"); // Switch to alternate screen buffer
    try w.writeAll("\x1b[?1006l\x1b[?1015l\x1b[?1002l\x1b[?1000l"); // Disable various mouse protocols
    try w.writeAll("\x1b[?1049h"); // Enable alternate screen buffer
    try w.writeAll("\x1b[?1000h"); // Enable mouse click tracking
    try w.writeAll("\x1b[?1036h"); // Enable meta key sends escape
    try w.writeAll("\x1b[?1037h"); // Enable DEL sends escape sequence
    try w.writeAll("\x1b[?1006h"); // Enable SGR mouse mode
    try w.writeAll("\x1b[2J"); // Clear entire screen

    try buffered_writer.flush();

    return;
}

pub fn deinit() !void {
    const w = buffered_writer.writer();

    // reverting terminal magic spells
    try w.writeAll("\x1b[?1000h\x1b[?1002h\x1b[?1015h\x1b[?1006h"); // Enable various mouse protocols
    try w.writeAll("\x1b[?1006l"); // Disable SGR mouse mode
    try w.writeAll("\x1b[?1037l"); // Disable DEL sends escape sequence
    try w.writeAll("\x1b[?1036l"); // Disable meta key sends escape
    try w.writeAll("\x1b[?1000l"); // Disable mouse click tracking
    try w.writeAll("\x1b[?25h"); // Show cursor
    try w.writeAll("\x1b[?1049l"); // Disable alternate screen buffer
    try w.writeAll("\x1b[?47l"); // Switch back to main screen buffer
    try w.writeAll("\x1b[u"); // Restore cursor position
    try w.writeAll("\x1b[2K\r"); // Clear current line and move cursor to beginning

    // restoring original termios config
    try os.tcsetattr(main.in.handle, .FLUSH, original_term);

    try buffered_writer.flush();
}

fn handleSigWinch(_: c_int) callconv(.C) void {
    terminal_size = getTerminalSize();

    const w = buffered_writer.writer();

    utils.moveCursor(w, 1, 1) catch {};
    w.writeByteNTimes(' ', terminal_size.height * terminal_size.width) catch {};

    loop_config.output(w, terminal_size);

    buffered_writer.flush() catch {};
}

fn getTerminalSize() TerminalSize {
    var win_size = mem.zeroes(os.system.winsize);
    const err = os.system.ioctl(main.in.handle, os.system.T.IOCGWINSZ, @intFromPtr(&win_size));

    if (os.errno(err) != .SUCCESS) {
        @panic("failed to measure terminal size");
    }

    return .{
        .height = win_size.row,
        .width = win_size.col,
    };
}

/// Use this function to provide to the terminal struct functions
/// that should run when the step() function is called.
///
/// (these handlers have to be received by this function and stored on the terminal struct instead of directly given to the step() because otherwise the handleSigWinch() wouldn't knew which draw function to run after the user reajusts the terminal windows size.)
pub fn withHandlers(loopConfig: TerminalLoopConfig) void {
    // instead of directly assigning loop_config = loopConfig
    // we check if the functions changed since the user(me) can
    // unintentionally call withHandlers() when is not necessary.
    // (this used to cause a "blip" bc the terminal were cleared and then draw with same content)

    if (loop_config.input != loopConfig.input) {
        loop_config.input = loopConfig.input;
    }

    if (loop_config.output != loopConfig.output) {
        loop_config.output = loopConfig.output;

        const w = buffered_writer.writer();

        // cleaning the terminal this way seems more predictable than using that ANSI sequence
        utils.moveCursor(w, 1, 1) catch {};
        w.writeByteNTimes(' ', terminal_size.height * terminal_size.width) catch {};

        buffered_writer.flush() catch {};
    }
}

/// Run input and output handlers provided through withHandlers() with
/// terminal context.
///
/// If an input handler function is defined, this function will wait
/// until user input to return, otherwise it'll only run the output handler and return.
pub fn step() void {
    const w = buffered_writer.writer();

    // execute given output function
    loop_config.output(w, terminal_size);
    buffered_writer.flush() catch {};

    if (loop_config.input) |input_fn| {
        // execute given input function
        var read_c: ?input.InputType = null;
        input.getKeyboardInput(&read_c, main.in, &new_term) catch {};

        input_fn(read_c);
    }
}
