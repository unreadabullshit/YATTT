const std = @import("std");
const mem = std.mem;
const os = std.posix;
const io = std.io;
const fs = std.fs;

const utils = @import("utils.zig");

const InputKind = enum { NORMAL, SPECIAL };
pub const InputType = union(InputKind) { NORMAL: u8, SPECIAL: ?[]const u8 };

pub fn getKeyboardInput(char: *InputType, in: fs.File) void {
    var read_buffer: [128]u8 = undefined;

    const bytes_read = in.read(&read_buffer) catch {
        char.* = .{ .SPECIAL = null };
        return;
    };

    if (bytes_read == 0) {
        char.* = .{ .SPECIAL = null };
        return;
    }

    if (bytes_read > 1) {
        char.* = .{ .SPECIAL = "OTHER" };
        // char.* = read_buffer[0..bytes_read];
        return;
    }

    switch (read_buffer[0]) {
        '\x09' => {
            char.* = .{ .SPECIAL = "TAB" };
        },
        '\x08' => {
            char.* = .{ .SPECIAL = "BACKSPACE" };
        },
        '\x7f' => {
            char.* = .{ .SPECIAL = "DELETE" };
        },
        '\x0A' => {
            char.* = .{ .SPECIAL = "ENTER" };
        },
        '\x0d' => {
            char.* = .{ .SPECIAL = "RETURN" };
        },
        ' ' => {
            char.* = .{ .SPECIAL = "SPACE" };
        },
        '\x1b' => {
            char.* = .{ .SPECIAL = "ESC" };
        },
        else => {
            char.* = .{ .NORMAL = read_buffer[0] };
        },
    }

    return;
}
