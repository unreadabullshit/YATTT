const std = @import("std");
const utils = @import("utils.zig");

pub const Game = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    phrase: std.ArrayListUnmanaged(u8) = undefined,
    attempt: std.ArrayListUnmanaged(u8) = undefined,
    total_errors_commited_count: u32 = 0,
    final_errors_commited_count: u32 = 0,

    pub fn typeChar(self: *Self, char: u8) !void {
        if (self.attempt.items.len < self.phrase.items.len) {
            try self.attempt.append(self.allocator, char);

            if (char != self.phrase.items[self.attempt.items.len - 1]) {
                self.total_errors_commited_count += 1;
            }

            if (self.attempt.items.len == self.phrase.items.len) {}
        }
    }

    pub fn deleteChar(self: *Self) void {
        _ = self.attempt.popOrNull();
    }

    pub fn deleteWord(self: *Self) void {
        while (true) {
            const rmv = self.attempt.popOrNull();

            if (rmv == null) break;

            if (self.attempt.items.len == 0) break;

            if (self.attempt.items[self.attempt.items.len - 1] == ' ') break;
        }
    }
};

pub fn newGame(someAllocator: std.mem.Allocator) !*Game {
    const g = try someAllocator.create(Game);
    const rPhrase: []const u8 = "lorem ipsum sek emmet";

    g.phrase = try std.ArrayListUnmanaged(u8).initCapacity(someAllocator, rPhrase.len);
    g.attempt = try std.ArrayListUnmanaged(u8).initCapacity(someAllocator, rPhrase.len);
    g.allocator = someAllocator;

    try g.phrase.appendSlice(someAllocator, rPhrase);

    return g;
}
