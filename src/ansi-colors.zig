const terminal = @import("terminal.zig");

const colors = enum { WHITE, GRAY, RED, BLUE };
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

    pub fn useBlueForeground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cForeground == null or self.cForeground.? != .BLUE) {
            try w.writeAll("\x1b[38;5;31m");
            self.cForeground = .BLUE;
            return;
        }
    }

    pub fn useWhiteForeground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cForeground == null or self.cForeground.? != .WHITE) {
            try w.writeAll("\x1b[38;5;255m");
            self.cForeground = .WHITE;
            return;
        }
    }

    pub fn useGrayForeground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cForeground == null or self.cForeground.? != .GRAY) {
            try w.writeAll("\x1b[38;5;240m");
            self.cForeground = .GRAY;
            return;
        }
    }

    pub fn useRedForeground(self: *Self, w: terminal.EasyBufferedWriter.Writer) !void {
        if (self.cForeground == null or self.cForeground.? != .RED) {
            try w.writeAll("\x1b[38;5;124m");
            self.cForeground = .RED;
            return;
        }
    }
};
