const std = @import("std");
const builtin = @import("builtin");
const cli = @import("cli.zig");
const commands = @import("commands.zig");
const assert = std.debug.assert;

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
var arena_allocator: std.heap.ArenaAllocator = .init(std.heap.page_allocator);

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ arena_allocator.allocator(), false },
        };
    };
    defer {
        if (is_debug)
            _ = debug_allocator.deinit()
        else
            arena_allocator.deinit();
    }

    var arg_it = try std.process.ArgIterator.initWithAllocator(gpa);
    defer arg_it.deinit();

    const command = try cli.parseCommands(&arg_it);
    switch (command) {
        .init => try commands.init(),
        .@"cat-file" => std.debug.print("cat-file\n", .{}),
    }
}
