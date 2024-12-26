const std = @import("std");
const builtin = @import("builtin");

const terminal = @import("terminal.zig");
const utils = @import("utils.zig");
const output = @import("output.zig");
const input = @import("input.zig");

const STATE = enum { SETUP, REVIEW, TYPING, QUIT };

pub var in: std.fs.File = undefined;
var app_state: STATE = .SETUP;

pub fn main() !void {
    in = std.io.getStdIn();

    if (builtin.os.tag != .macos) {
        try in.writeAll("platform not implemented!\n");
        return;
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    const allocator = arena.allocator();

    try terminal.init(allocator);

    while (app_state != .QUIT) {
        if (app_state == .SETUP) {
            terminal.withHandlers(.{ .input = handlerWhileSetup, .output = drawWhileSetup });
            terminal.step();
        }

        if (app_state == .TYPING) {
            terminal.withHandlers(.{ .input = handlerWhileTyping, .output = drawWhileTyping });
            terminal.step();
        }

        if (app_state == .REVIEW) {
            // TODO
        }
    }

    defer {
        arena.deinit();

        terminal.deinit() catch {
            @panic("failed to restore terminal original state");
        };

        in.close();
    }
}

// TODO: move these functions somewhere else
fn drawWhileSetup(w: terminal.EasyBufferedWriter.Writer, ts: terminal.TerminalSize) void {
    output.displayText(w, ts, "setup", "larem ipsum") catch {};
    output.displayFooter(w, ts) catch {};
}

fn drawWhileTyping(w: terminal.EasyBufferedWriter.Writer, ts: terminal.TerminalSize) void {
    output.displayText(w, ts, "typing", "larem ipsum") catch {};
    output.displayFooter(w, ts) catch {};
}

fn handlerWhileSetup(someInput: input.InputType) void {
    switch (someInput) {
        .NORMAL => |char| {
            // TODO: add char to game attempt buffer
            _ = char;

            app_state = .TYPING;
        },
        .SPECIAL => |str| {
            if (str) |_str| {
                if (std.mem.eql(u8, _str, "ESC")) {
                    // "quit" app
                    app_state = .QUIT;
                }
            }
        },
    }
}

fn handlerWhileTyping(someInput: input.InputType) void {
    switch (someInput) {
        .NORMAL => |char| {
            _ = char;
            // TODO: add char to game attempt buffer
        },
        .SPECIAL => |str| {
            if (str) |_str| {
                if (std.mem.eql(u8, _str, "BACKSPACE") or std.mem.eql(u8, _str, "DELETE")) {
                    // TODO: remove last char from game attempt buffer
                }

                if (std.mem.eql(u8, _str, "ESC")) {
                    app_state = .SETUP;
                }

                if (std.mem.eql(u8, _str, "SPACE")) {
                    // TODO: add space char to game attempt buffer

                }
            }
        },
    }
}
