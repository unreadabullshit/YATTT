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
    // alignment: enum { start, center, end } = .start, // TODO: feat
    // justify: enum { start, center, end, between, around, evenly } = .start, // TODO: feat
    height: enum { auto, fit } = .auto,
    width: enum { auto, fit } = .auto,
    preferredToGrow: bool = false,

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
        const debug = false;
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

        const total_margin = self.margin * 2;
        const WWoMargin: usize = if (self.width == .auto) da.width - total_margin else min.width - total_margin; // width without margin
        const HWoMargin: usize = if (self.height == .auto) da.height - total_margin else min.height - total_margin; // height without margin
        const safe_width: usize = if (self.border) WWoMargin - 2 else WWoMargin; // width to work with taking into account possible border
        const safe_height: usize = if (self.border) HWoMargin - 2 else HWoMargin; // height to work with taking into account possible border
        const container_draw_col_pointer = da.col + self.margin; // starting col
        const container_draw_row_pointer = da.row + self.margin; // starting row
        const border_offset: usize = if (self.border) 1 else 0;

        if (debug) {
            const sub_border: usize = if (!self.border) 1 else 0;
            for (da.row..da.row + da.height) |r| {
                for (da.col..da.col + da.width) |c| {
                    // draw vertical padding
                    if ((r > container_draw_row_pointer - sub_border and r <= container_draw_row_pointer + self.padding - sub_border) or (r > container_draw_row_pointer + safe_height - self.padding - sub_border and r <= container_draw_row_pointer + safe_height - sub_border)) {
                        try utils.moveCursor(w, r, c);
                        try ansi.useBlueBackground(w);
                        try w.writeAll("\u{00B7}");
                        try ansi.resetBackground(w);
                    }

                    // draw horizontal padding
                    if ((c > container_draw_col_pointer - sub_border and c <= container_draw_col_pointer + self.padding - sub_border) or (c > container_draw_col_pointer + safe_width - self.padding - sub_border and c <= container_draw_col_pointer + safe_width - sub_border)) {
                        try utils.moveCursor(w, r, c);
                        try ansi.useBlueBackground(w);
                        try w.writeAll("\u{00B7}");
                        try ansi.resetBackground(w);
                    }

                    // draw vertical margin
                    if (r < container_draw_row_pointer or r + border_offset > da.row + da.height - self.margin - sub_border) {
                        try utils.moveCursor(w, r, c);
                        try ansi.useGreenBackground(w);
                        try w.writeAll("\u{00A4}");
                        try ansi.resetBackground(w);
                    }

                    // draw horizontal margin
                    if (c < container_draw_col_pointer or c + border_offset > da.col + da.width - self.margin - sub_border) {
                        try utils.moveCursor(w, r, c);
                        try ansi.useGreenBackground(w);
                        try w.writeAll("\u{00A4}");
                        try ansi.resetBackground(w);
                    }
                }
            }
        }

        try utils.moveCursor(w, container_draw_row_pointer, container_draw_col_pointer);

        // draw border, if necessary
        if (self.border) {
            while (aux_row <= HWoMargin) : (aux_row += 1) {
                const next_row = container_draw_row_pointer + aux_row;

                // first line
                if (aux_row == 1) {
                    if (debug) try ansi.useRedBackground(w);
                    try w.writeAll("\u{250C}"); // '┌'
                    try w.writeBytesNTimes("\u{2500}", safe_width); // ─
                    try w.writeAll("\u{2510}"); // ┐
                    if (debug) try ansi.resetBackground(w);

                    try utils.moveCursor(w, next_row, container_draw_col_pointer);

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
                try utils.moveCursor(w, next_row - 1, container_draw_col_pointer + 1 + safe_width); // skip "inside" cols
                try w.writeAll("\u{2502}"); // │
                if (debug) try ansi.resetBackground(w);

                try utils.moveCursor(w, next_row, container_draw_col_pointer);
            }
        }

        // draw children
        if (self.children) |children| {
            const max_height: usize = safe_height - (self.padding * 2);
            const max_width: usize = safe_width - (self.padding * 2);

            var available_auto_height = max_height;
            var available_auto_width = max_width;
            var autoQty: usize = 0;
            var children_preferred_to_grow: ?usize = null;

            // Calculate how many .auto width and height elements there is
            // and how much space are available for them to grow, also looking
            // for the first .auto child with preferredToGrow
            for (children, 0..) |c, idx| {
                const cMin = c.calcMinSize();
                var marked_to_grow = false;

                if (self.direction == .row) {
                    if (c.width == .fit) {
                        available_auto_width = math.sub(usize, available_auto_width, cMin.width) catch 0;
                    } else {
                        if (c.preferredToGrow) marked_to_grow = true;
                        autoQty += 1;
                    }
                }

                if (self.direction == .column) {
                    if (c.height == .fit) {
                        available_auto_height = math.sub(usize, available_auto_height, cMin.height) catch 0;
                    } else {
                        if (c.preferredToGrow) marked_to_grow = true;
                        autoQty += 1;
                    }
                }

                if (marked_to_grow and children_preferred_to_grow == null) {
                    children_preferred_to_grow = idx;
                }
            }

            var used_height: usize = 0;
            var used_width: usize = 0;

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
                var forced: ?enum { H, W } = null;
                // const c_border_offset: usize = if (c.border) 2 else 0;

                if (c.height == .fit and self.direction == .column) {
                    if (used_height + cMin.height <= max_height) {
                        H = cMin.height;
                    }

                    if (used_height + cMin.height > max_height and max_height - used_height <= 0) {
                        H = 1;
                        forced = .H;
                    }

                    if (used_height + cMin.height > max_height and max_height - used_height > 0) {
                        H = @min(max_height - used_height, cMin.height);
                    }
                } else if (c.height == .fit and self.direction == .row) {
                    H = @min(available_auto_height, cMin.height);
                } else if (c.height == .auto and self.direction == .column) {
                    if (available_auto_height / autoQty >= 1) {
                        H = available_auto_height / autoQty;
                    } else {
                        H = 1;
                        forced = .H;
                    }
                } else if (c.height == .auto and self.direction == .row) {
                    H = available_auto_height;
                }

                if (c.width == .fit and self.direction == .row) {
                    if (used_width + cMin.width <= max_width) {
                        W = cMin.width;
                    }

                    if (used_width + cMin.width > max_width and max_width - used_width < 1) {
                        W = 1;
                        forced = .W;
                    }

                    if (used_width + cMin.width > max_width and max_width - used_width >= 1) {
                        W = @min(max_width - used_width, cMin.width);
                    }
                } else if (c.width == .fit and self.direction == .column) {
                    // no need to ensure at least W >= 1 or anything like that
                    W = @min(available_auto_width, cMin.width);
                } else if (c.width == .auto and self.direction == .row) {
                    if (available_auto_width / autoQty > 1) {
                        W = available_auto_width / autoQty;
                    } else {
                        W = 1;
                        forced = .W;
                    }
                } else if (c.width == .auto and self.direction == .column) {
                    W = available_auto_width;
                }

                if (forced) |d| {
                    var reverse_idx: usize = idx;

                    // "steal" width from sibling width = .fit container
                    while (reverse_idx > 0) : (reverse_idx -= 1) {
                        if (d == .W) {
                            if (child_sizes[reverse_idx - 1].width > 1) {
                                child_sizes[reverse_idx - 1].width -= 1;
                                used_width -= 1;
                                available_auto_width += 1;
                                break;
                            }
                        }

                        if (d == .H) {
                            if (child_sizes[reverse_idx - 1].height > 1) {
                                child_sizes[reverse_idx - 1].height -= 1;
                                used_height -= 1;
                                available_auto_height += 1;
                                break;
                            }
                        }
                    }
                }

                child_sizes[idx] = .{
                    .row = undefined,
                    .col = undefined,
                    .width = W,
                    .height = H,
                };

                if (self.direction == .row) {
                    used_width += W;
                }

                if (self.direction == .column) {
                    used_height += H;
                }
            }

            // re-calculating child_sizes bc of a bug I couldn't fix
            // on the previous loop(this is an AI fix btw).
            var current_row: usize = container_draw_row_pointer + self.padding + border_offset;
            var current_col: usize = container_draw_col_pointer + self.padding + border_offset;
            for (child_sizes) |*size| {
                size.row = current_row;
                size.col = current_col;

                if (self.direction == .column) {
                    current_row += size.height;
                } else {
                    current_col += size.width;
                }
            }

            // Deal with unused spaces caused by .auto sizing containers
            // eg: if you have 4 containers with width .auto on an 82 col terminal
            // eventually 2 cols will be unused since they cant be evenly distributed
            // between the 4 containers.

            // try utils.moveCursor(w, 1, 3);
            // try w.print("preferred: {any} / distribute: {any} / available: {any}", .{ children_preferred_to_grow, self.direction == .column and child_sizes[child_sizes.len - 1].row - border_offset + child_sizes[child_sizes.len - 1].height - 1 < max_height, max_height - ((child_sizes[child_sizes.len - 1].row - border_offset) + (child_sizes[child_sizes.len - 1].height - 1)) });
            if (self.direction == .column and child_sizes[child_sizes.len - 1].row - border_offset + child_sizes[child_sizes.len - 1].height - 1 < max_height) {
                const unused: usize = max_height - ((child_sizes[child_sizes.len - 1].row - border_offset) + (child_sizes[child_sizes.len - 1].height - 1));

                if (children_preferred_to_grow) |preferred| {
                    child_sizes[preferred].height += unused;

                    for (0..child_sizes.len) |idx| {
                        if (idx <= preferred) continue;

                        child_sizes[idx].row += unused;
                    }
                }

                // TODO: distribute the unused space between elements if there isn't
                // an element to preferably grow.
            }

            // try utils.moveCursor(w, 1, 3);
            // try w.print("preferred: {any} / distribute: {any} / available: {any}", .{ children_preferred_to_grow, self.direction == .row and child_sizes[child_sizes.len - 1].col - border_offset + child_sizes[child_sizes.len - 1].width - 1 < max_width, max_width - ((child_sizes[child_sizes.len - 1].col - border_offset) + (child_sizes[child_sizes.len - 1].width - 1)) });
            if (self.direction == .row and child_sizes[child_sizes.len - 1].col - border_offset + child_sizes[child_sizes.len - 1].width - 1 < max_width) {
                const unused: usize = max_width - ((child_sizes[child_sizes.len - 1].col - border_offset) + (child_sizes[child_sizes.len - 1].width - 1));

                if (children_preferred_to_grow) |preferred| {
                    child_sizes[preferred].width += unused;

                    for (0..child_sizes.len) |idx| {
                        if (idx <= preferred) continue;

                        child_sizes[idx].col += unused;
                    }
                }

                // TODO: distribute the unused space between elements if there isn't
                // an element to preferably grow.
            }

            for (children, child_sizes, 0..) |c, size, idx| {
                _ = idx;
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

// const TextNode = struct {
//     const Self = @This();

//     text: []u8,
//     textForeground: with_ansi.colors,
//     textBackground: with_ansi.colors,

//     fn calcMinSize() void {}
//     fn render() void {}
// };
