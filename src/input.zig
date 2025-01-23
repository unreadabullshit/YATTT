const std = @import("std");

const mem = std.mem;
const os = std.posix;
const io = std.io;
const fs = std.fs;

const utils = @import("utils.zig");

const SpecialKeys = enum { TAB, DELETE, W_DELETE, ENTER, RETURN, SPACE, ESC, ARROW_UP, ARROW_DOWN, ARROW_LEFT, ARROW_RIGHT };
const InputKind = enum { LETTER, SPECIAL, CTRL };
pub const InputType = union(InputKind) { LETTER: u8, SPECIAL: SpecialKeys, CTRL: u8 };

pub fn getKeyboardInput(char: *?InputType, in: fs.File, raw: *os.termios) !void {
    var read_buffer: [1]u8 = undefined;

    const read_bytes = try in.read(&read_buffer);

    // since we are setting os.system.V.TIME on termios,
    // we shouldn't get an empty buffer, but if we change that in
    // the future, remember to handle it properly here.
    if (read_bytes == 0) {
        return;
    }

    // handle escape sequencies(ESC+something)
    if (read_buffer[0] == '\x1B') {
        raw.cc[@intFromEnum(os.system.V.TIME)] = 1;
        raw.cc[@intFromEnum(os.system.V.MIN)] = 0;
        try os.tcsetattr(in.handle, .NOW, raw.*);

        // read the rest of bytes(if any)
        var esc_buffer: [128]u8 = undefined;
        const esc_bytes = try in.read(&esc_buffer);

        raw.cc[@intFromEnum(os.system.V.TIME)] = 0;
        raw.cc[@intFromEnum(os.system.V.MIN)] = 1;
        try os.tcsetattr(in.handle, .NOW, raw.*);

        // ESC can actually be sent solo(when user just presses ESC key).
        if (esc_bytes == 0) {
            char.* = .{ .SPECIAL = .ESC };
            return;
        }

        // opt-del
        if (esc_bytes == 1 and esc_buffer[0] == '\x7f') {
            char.* = .{ .SPECIAL = .W_DELETE };
        }

        // Ctrl+i and "Ctrl+m" actually sends an escape sequence(on mac, not sure other platforms)
        if (std.mem.eql(u8, esc_buffer[0..esc_bytes], "[105;5u")) {
            char.* = .{ .CTRL = 'i' };
        }

        if (std.mem.eql(u8, esc_buffer[0..esc_bytes], "[109;5u")) {
            char.* = .{ .CTRL = 'm' };
        }

        // arrow keys
        if (std.mem.eql(u8, esc_buffer[0..esc_bytes], "[A")) {
            char.* = .{ .SPECIAL = .ARROW_UP };
        }

        if (std.mem.eql(u8, esc_buffer[0..esc_bytes], "[B")) {
            char.* = .{ .SPECIAL = .ARROW_DOWN };
        }

        if (std.mem.eql(u8, esc_buffer[0..esc_bytes], "[D")) {
            char.* = .{ .SPECIAL = .ARROW_LEFT };
        }

        if (std.mem.eql(u8, esc_buffer[0..esc_bytes], "[C")) {
            char.* = .{ .SPECIAL = .ARROW_RIGHT };
        }

        return;
    }

    // handle Ctrl+[a-z]
    const chars = [26]u8{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' };
    for (chars) |_char| {
        // Ctrl + "i" and "m" send escape sequences when pressed so they won't trigger this and should be handled above.
        if (read_buffer[0] == _char & '\x1F') {
            char.* = .{ .CTRL = _char };

            return;
        }
    }

    // known "special" chars & else which should capture [a-z]
    switch (read_buffer[0]) {
        '\x09' => {
            char.* = .{ .SPECIAL = .TAB };
        },
        '\x7f' => {
            char.* = .{ .SPECIAL = .DELETE };
        },
        '\x0A' => {
            char.* = .{ .SPECIAL = .ENTER };
        },
        '\x0d' => {
            char.* = .{ .SPECIAL = .RETURN };
        },
        '\x20' => {
            char.* = .{ .SPECIAL = .SPACE };
        },
        else => {
            if (read_buffer[0] > 32 and read_buffer[0] < 127) {
                char.* = .{ .LETTER = read_buffer[0] };
            }
        },
    }

    return;
}
