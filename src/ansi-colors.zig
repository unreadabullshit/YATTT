const terminal = @import("terminal.zig");

pub const colors = enum { WHITE, GRAY, RED, BLUE, GREEN };
const styles = enum { UNDERLINE, NOUNDERLINE };

/// using this struct to write escape sequencies to the
/// terminal and prevent from changing unnecessary styles.
pub const ANSI = struct {
    const Self = @This();

    cForeground: ?colors = null,
    cBackground: ?colors = null,
    cStyle: ?styles = null,

    pub fn withUnderline(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cStyle == null or self.cStyle.? != .UNDERLINE) {
            try w.writeAll("\x1b[4m");
            self.cStyle = .UNDERLINE;
            return;
        }
    }

    pub fn withoutUnderline(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cStyle != null and self.cStyle.? == .UNDERLINE) {
            try w.writeAll("\x1b[24m");
            self.cStyle = .NOUNDERLINE;
            return;
        }
    }

    // FOREGROUNDS
    pub fn useBlueForeground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cForeground == null or self.cForeground.? != .BLUE) {
            try w.writeAll("\x1b[34m");
            self.cForeground = .BLUE;
            return;
        }
    }

    pub fn useWhiteForeground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cForeground == null or self.cForeground.? != .WHITE) {
            try w.writeAll("\x1b[37m");
            self.cForeground = .WHITE;
            return;
        }
    }

    pub fn useGrayForeground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cForeground == null or self.cForeground.? != .GRAY) {
            try w.writeAll("\x1b[90m");
            self.cForeground = .GRAY;
            return;
        }
    }

    pub fn useRedForeground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cForeground == null or self.cForeground.? != .RED) {
            try w.writeAll("\x1b[31m");
            self.cForeground = .RED;
            return;
        }
    }

    // BACKGROUNDS
    pub fn useRedBackground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cBackground == null or self.cBackground.? != .RED) {
            try w.writeAll("\x1b[41m");
            self.cBackground = .RED;
            return;
        }
    }

    pub fn useBlueBackground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cBackground == null or self.cBackground.? != .BLUE) {
            try w.writeAll("\x1b[44m");
            self.cBackground = .BLUE;
            return;
        }
    }

    pub fn useGreenBackground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cBackground == null or self.cBackground.? != .GREEN) {
            try w.writeAll("\x1b[42m");
            self.cBackground = .GREEN;
            return;
        }
    }

    pub fn resetBackground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cBackground != null) {
            try w.writeAll("\x1b[49m");
            self.cBackground = null;
            return;
        }
    }

    pub fn resetForeground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cForeground != null) {
            try w.writeAll("\x1b[39m");
            self.cForeground = null;
            return;
        }
    }
};
