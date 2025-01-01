const std = @import("std");
const builtin = @import("builtin");

const terminal = @import("terminal.zig");
const utils = @import("utils.zig");
const output = @import("output.zig");
const input = @import("input.zig");
const game = @import("game.zig");

const STATE = enum { SETUP, REVIEW, TYPING, QUIT };

pub var in: std.fs.File = undefined;

var app_state: STATE = .SETUP;
var g: *game.Game = undefined;

pub fn main() !void {
    in = std.io.getStdIn();

    if (builtin.os.tag != .macos) {
        try in.writeAll("platform not implemented!\n");
        return;
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    const allocator = arena.allocator();

    try terminal.init(allocator);
    g = try game.newGame(allocator);

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
    output.displayText(w, ts, "setup", "") catch {};
    output.displayFooter(w, ts) catch {};
}

fn drawWhileTyping(w: terminal.EasyBufferedWriter.Writer, ts: terminal.TerminalSize) void {
    output.displayText(w, ts, g.phrase.items[0..], g.attempt.items[0..]) catch {};
    output.displayFooter(w, ts) catch {};
}

fn handlerWhileSetup(someInput: ?input.InputType) void {
    if (someInput) |_input| {
        switch (_input) {
            .LETTER => |char| {
                g.typeChar(char) catch {};

                app_state = .TYPING;
            },
            .SPECIAL => |key| {
                if (key == .ESC) {
                    // "quit" app
                    app_state = .QUIT;
                }
            },
            else => {},
        }
    }
}

fn handlerWhileTyping(someInput: ?input.InputType) void {
    if (someInput) |_input| {
        switch (_input) {
            .LETTER => |char| {
                g.typeChar(char) catch {};
            },
            .SPECIAL => |key| {
                if (key == .BACKSPACE or key == .DELETE) {
                    g.deleteChar();
                }

                if (key == .ESC) {
                    app_state = .SETUP;
                }

                if (key == .SPACE) {
                    g.typeChar(' ') catch {};
                }
            },
            else => {},
        }
    }
}
