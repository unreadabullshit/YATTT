const std = @import("std");
const builtin = @import("builtin");

const terminal = @import("terminal.zig");
const utils = @import("utils.zig");
const output = @import("output.zig");
const input = @import("input.zig");
const game = @import("game.zig");
const trm = @import("text-render-machine.zig");

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

fn drawWhileSetup(w: terminal.EasyBufferedWriter.Writer, ts: terminal.TerminalSize) void {
    const children = &[_]trm.ContainerNode{
        .{ .border = true, .children = null, .height = .auto, .width = .auto, .margin = 0, .padding = 0 },
        .{ .border = true, .children = null, .height = .auto, .width = .auto, .margin = 1, .padding = 1 },
        .{ .border = true, .children = null, .height = .auto, .width = .auto, .margin = 2, .padding = 2 },
        .{ .border = true, .children = null, .height = .auto, .width = .auto, .margin = 3, .padding = 3 },
    };

    const initial_da = trm.DrawArea{ .height = ts.height, .width = ts.width, .col = 1, .row = 1 };

    const node = trm.ContainerNode{ .border = true, .direction = .row, .children = @constCast(children), .margin = 0, .padding = 0, .height = .auto, .width = .auto };

    node.render(
        w,
        initial_da,
    ) catch {};
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
                if (key == .DELETE) {
                    g.deleteChar();
                }

                if (key == .W_DELETE) {
                    g.deleteWord();
                }

                if (key == .ESC) {
                    g.attempt.deinit(g.allocator);
                    g.phrase.deinit(g.allocator);

                    g = game.newGame(g.allocator) catch {
                        unreachable;
                    };

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
