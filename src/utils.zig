const std = @import("std");

const terminal = @import("terminal.zig");

pub fn moveCursor(w: terminal.EasyBufferedWriter.Writer, row: usize, col: usize) !void {
    _ = try w.print("\x1b[{};{}H", .{ row, col });
}
