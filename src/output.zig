const std = @import("std");
const terminal = @import("terminal.zig");
const utils = @import("utils.zig");

var ansi = @import("ansi-colors.zig").ANSI{};

// TODO: improve this fn logic
pub fn displayText(w: terminal.EasyBufferedWriter.Writer, ts: terminal.TerminalSize, phrase: []const u8, attempt: []const u8) !void {
    var row: usize = 10;
    var col: usize = 20;
    var shouldGoDown = false;

    try utils.moveCursor(w, row, col);

    for (phrase, 0..) |p, idx| {
        var c: ?u8 = undefined;

        if (idx >= attempt.len) {
            c = null;
        } else {
            c = attempt[idx];
        }

        if (shouldGoDown) {
            row += 1;
            col = 20;

            shouldGoDown = false;

            try utils.moveCursor(w, row, col);
        }

        if (col > ts.width - 30 and p == ' ') {
            shouldGoDown = true;
        }

        col += 1;

        if (idx == attempt.len) {
            try ansi.withUnderline(w);
            try ansi.useBlueForeground(w);
            try w.writeAll(&[1]u8{p});

            continue;
        }

        if (c == null) {
            try ansi.withoutUnderline(w);
            try ansi.useGrayForeground(w);
            try w.writeAll(&[1]u8{p});

            continue;
        }

        if (p != c) {
            try ansi.withoutUnderline(w);
            try ansi.useRedForeground(w);
            try w.writeAll(&[1]u8{p});

            continue;
        }

        try ansi.withoutUnderline(w);
        try ansi.useWhiteForeground(w);
        try w.writeAll(&[1]u8{p});
    }
}

pub fn displayFooter(w: terminal.EasyBufferedWriter.Writer, ts: terminal.TerminalSize) !void {
    try ansi.useWhiteForeground(w);
    try utils.moveCursor(w, ts.height, 0);

    try w.writeAll("\x1b]8;;https://github.com/unreadabullshit/YATTT\x1b\\github\x1b]8;;\x1b\\");
}
