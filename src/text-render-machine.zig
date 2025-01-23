const terminal = @import("terminal.zig");
const with_ansi = @import("ansi-colors.zig");
const utils = @import("utils.zig");
const std = @import("std");
const math = std.math;

var ansi = with_ansi.ANSI{};

pub const DrawArea = struct {
    row: usize,
    col: usize,
    width: usize,
    height: usize,
};

pub const ContainerNode = struct {
    const Self = @This();

    margin: usize = 0,
    padding: usize = 0,

    direction: enum { row, column } = .row, // TODO: add row-reverse and column-reverse
    // aligniment: enum { start, center, end } = .start, // TODO
    // justify: enum { start, center, end, between, around, evenly } = .start, // TODO
    height: enum { auto, fit } = .auto,
    width: enum { auto, fit } = .auto,

    border: bool,

    children: ?[]Self,

    pub fn calcMinSize(self: *const Self) struct { height: usize, width: usize } {
        var min_height: usize = 1;
        var min_width: usize = 1;

        // min height and width has to be 1 when there is no children because otherwise
        // it would be possible to have a 0 safe content space inside the container, which
        // would look "normal" on containers with border but would make absolute
        // no sense on the other case, like:

        // ┌┐   This is an min size 0 container with borders, which looks somewhat "ok",
        // └┘   but how would you draw this without the borders? You cant!

        if (self.children) |arr| {
            if (self.direction == .row) {
                min_width = arr.len;
            }

            if (self.direction == .column) {
                min_height = arr.len;
            }
        }

        if (self.border) {
            min_height += 2;
            min_width += 2;
        }

        if (self.margin > 0) {
            min_height += self.margin * 2;
            min_width += self.margin * 2;
        }

        if (self.padding > 0) {
            min_height += self.padding * 2;
            min_width += self.padding * 2;
        }

        return .{ .height = min_height, .width = min_width };
    }

    pub fn render(self: *const Self, w: terminal.EasyBufferedWriter.Writer, da: DrawArea) !void {
        const debug = true;
        const min = calcMinSize(self);
        var aux_row: usize = 1;
        // var aux_col: usize = 1;

        // to be rendered when there is no minimal space for the container
        if (da.height < min.height or da.width < min.width) {
            try utils.moveCursor(w, da.row, da.col);

            while (aux_row <= da.height) : (aux_row += 1) {
                try w.writeBytesNTimes("░", da.width);
                try utils.moveCursor(w, da.row + aux_row, da.col);
            }

            // try w.print("░ - ▒ - ▓", .{});

            return;
        }

        const tMargin = self.margin * 2; // total margin
        const WWoMargin: usize = if (self.width == .auto) da.width - tMargin else min.width - tMargin; // width without margin
        const HWoMargin: usize = if (self.height == .auto) da.height - tMargin else min.height - tMargin; // height without margin
        const safe_width: usize = if (self.border) WWoMargin - 2 else WWoMargin; // width to work with taking into account possible border
        const safe_height: usize = if (self.border) HWoMargin - 2 else HWoMargin; // height to work with taking into account possible border
        const draw_col_pointer = da.col + self.margin; // starting col
        const draw_row_pointer = da.row + self.margin; // starting row
        const border_offset: usize = if (self.border) 1 else 0;

        if (debug) {
            const sub_border: usize = if (!self.border) 1 else 0;
            for (da.row..da.row + da.height) |r| {
                for (da.col..da.col + da.width) |c| {

                    // draw vertical padding
                    if ((r > draw_row_pointer - sub_border and r <= draw_row_pointer + self.padding - sub_border) or (r > draw_row_pointer + safe_height - self.padding - sub_border and r <= draw_row_pointer + safe_height - sub_border)) {
                        try utils.moveCursor(w, r, c);
                        try ansi.useBlueBackground(w);
                        try w.writeAll("\u{00B7}");
                        try ansi.resetBackground(w);
                    }

                    // draw horizontal padding
                    if ((c > draw_col_pointer - sub_border and c <= draw_col_pointer + self.padding - sub_border) or (c > draw_col_pointer + safe_width - self.padding - sub_border and c <= draw_col_pointer + safe_width - sub_border)) {
                        try utils.moveCursor(w, r, c);
                        try ansi.useBlueBackground(w);
                        try w.writeAll("\u{00B7}");
                        try ansi.resetBackground(w);
                    }

                    // draw vertical margin
                    if (r < draw_row_pointer or r + border_offset > da.row + da.height - self.margin - sub_border) {
                        try utils.moveCursor(w, r, c);
                        try ansi.useGreenBackground(w);
                        try w.writeAll("\u{00A4}");
                        try ansi.resetBackground(w);
                    }

                    // draw horizontal margin
                    if (c < draw_col_pointer or c + border_offset > da.col + da.width - self.margin - sub_border) {
                        try utils.moveCursor(w, r, c);
                        try ansi.useGreenBackground(w);
                        try w.writeAll("\u{00A4}");
                        try ansi.resetBackground(w);
                    }
                }
            }
        }

        try utils.moveCursor(w, draw_row_pointer, draw_col_pointer);

        // draw border, if necessary
        if (self.border) {
            while (aux_row <= HWoMargin) : (aux_row += 1) {
                const next_row = draw_row_pointer + aux_row;

                // first line
                if (aux_row == 1) {
                    if (debug) try ansi.useRedBackground(w);
                    try w.writeAll("\u{250C}"); // '┌'
                    try w.writeBytesNTimes("\u{2500}", safe_width); // ─
                    try w.writeAll("\u{2510}"); // ┐
                    if (debug) try ansi.resetBackground(w);

                    try utils.moveCursor(w, next_row, draw_col_pointer);

                    continue;
                }

                // last line
                if (aux_row == HWoMargin) {
                    if (debug) try ansi.useRedBackground(w);
                    try w.writeAll("\u{2514}"); // └
                    try w.writeBytesNTimes("\u{2500}", safe_width); // ─
                    try w.writeAll("\u{2518}"); // ┘
                    if (debug) try ansi.resetBackground(w);

                    continue;
                }

                // lines in between
                if (debug) try ansi.useRedBackground(w);
                try w.writeAll("\u{2502}"); // │
                try utils.moveCursor(w, next_row - 1, draw_col_pointer + 1 + safe_width); // skip "inside" cols
                try w.writeAll("\u{2502}"); // │
                if (debug) try ansi.resetBackground(w);

                try utils.moveCursor(w, next_row, draw_col_pointer);
            }
        }

        if (self.children) |children| {
            const max_height: usize = safe_height - (self.padding * 2);
            const max_width: usize = safe_width - (self.padding * 2);

            var available_auto_height = max_height;
            var available_auto_width = max_width;
            var autoQty: usize = 0;

            // calculate how many .auto width and height elements there is
            // and how much space are available for them to grow
            for (children) |c| {
                const cMin = c.calcMinSize();

                if (self.direction == .row) {
                    if (c.width == .fit) {
                        available_auto_width = math.sub(usize, available_auto_width, cMin.width) catch 0;
                    } else {
                        autoQty += 1;
                    }
                }

                if (self.direction == .column) {
                    if (c.height == .fit) {
                        available_auto_height = math.sub(usize, available_auto_height, cMin.height) catch 0;
                    } else {
                        autoQty += 1;
                    }
                }
            }

            var cRow = draw_row_pointer + self.padding + border_offset; // children row
            var cCol = draw_col_pointer + self.padding + border_offset; // children column

            var child_sizes = try std.heap.raw_c_allocator.alloc(DrawArea, children.len);
            defer std.heap.raw_c_allocator.free(child_sizes);

            // calculating the height and width of each container
            // based on its size spec(.auto or .fit) and the parent container
            // direction(.row or .column), then pushing to child_sizes, which
            // will be used to render each container.
            for (children, 0..) |c, idx| {
                const cMin = c.calcMinSize();

                var H: usize = undefined;
                var W: usize = undefined;
                const c_border_offset: usize = if (c.border) 2 else 0;

                if (c.height == .fit and self.direction == .column) {
                    if (cRow + cMin.height <= max_height + c_border_offset) {
                        H = cMin.height;
                    } else if (max_height < cRow - 1) {
                        H = 1;

                        // Start from the previous container and work backwards(ai)
                        var needed_space = cRow - (max_height + 1);
                        var current_idx = idx;
                        while (needed_space > 0 and current_idx > 0) {
                            current_idx -= 1;
                            if (child_sizes[current_idx].height > 1) {
                                const can_reduce = @min(child_sizes[current_idx].height - 1, needed_space);
                                child_sizes[current_idx].height -= can_reduce;
                                cRow -= can_reduce;
                                needed_space -= can_reduce;
                            }
                        }
                    } else {
                        H = c_border_offset + max_height - cRow;
                    }
                } else if (c.height == .fit and self.direction == .row) {
                    H = @min(available_auto_height, cMin.height);
                } else if (c.height == .auto and self.direction == .column) {
                    H = available_auto_height / autoQty;
                } else if (c.height == .auto and self.direction == .row) {
                    H = available_auto_height;
                }

                if (c.width == .fit and self.direction == .row) {
                    if (cCol + cMin.width <= max_width + c_border_offset) {
                        W = cMin.width;
                    } else if (max_width < cCol - 1) {
                        W = 1;

                        // Start from the previous container and work backwards(ai)
                        var needed_space = cCol - (max_width + 1);
                        var current_idx = idx;
                        while (needed_space > 0 and current_idx > 0) {
                            current_idx -= 1;
                            if (child_sizes[current_idx].width > 1) {
                                const can_reduce = @min(child_sizes[current_idx].width - 1, needed_space);
                                child_sizes[current_idx].width -= can_reduce;
                                cCol -= can_reduce;
                                needed_space -= can_reduce;
                            }
                        }
                    } else {
                        W = c_border_offset + max_width - cCol;
                    }
                } else if (c.width == .fit and self.direction == .column) {
                    W = @min(available_auto_width, cMin.width);
                } else if (c.width == .auto and self.direction == .row) {
                    W = available_auto_width / autoQty;
                } else if (c.width == .auto and self.direction == .column) {
                    W = available_auto_width;
                }

                child_sizes[idx] = .{
                    .row = cRow,
                    .col = cCol,
                    .width = W,
                    .height = H,
                };

                if (self.direction == .row) {
                    cCol += W;
                }

                if (self.direction == .column) {
                    cRow += H;
                }
            }

            // re-calculating child_sizes bc of a bug I couldn't fix
            // on the previous loop(this is an AI fix btw).
            var current_row = child_sizes[0].row;
            var current_col = child_sizes[0].col;
            for (child_sizes) |*size| {
                if (self.direction == .column) {
                    size.row = current_row;
                    current_row += size.height;
                } else {
                    size.col = current_col;
                    current_col += size.width;
                }
            }

            for (children, child_sizes) |c, size| {
                try c.render(w, .{
                    .row = size.row,
                    .col = size.col,
                    .width = size.width,
                    .height = size.height,
                });
            }
        }
    }
};

const TextNode = struct {
    const Self = @This();

    text: []u8,
    textForeground: with_ansi.colors,
    textBackground: with_ansi.colors,

    fn calcMinSize() void {}
    fn render() void {}
};
