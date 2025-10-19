const std = @import("std");
const builtin = @import("builtin");
const cli = @import("cli.zig");
const commands = @import("commands.zig");
const assert = std.debug.assert;

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
var arena_allocator: std.heap.ArenaAllocator = .init(std.heap.page_allocator);

pub fn main() !u8 {
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
    var stdout_buf: [64]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

    var stderr_buf: [64]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_writer.interface;

    var arg_it = try std.process.ArgIterator.initWithAllocator(gpa);
    defer arg_it.deinit();

    const command = cli.parseCommands(&arg_it, stderr) catch |err| {
        if (is_debug) return err;
        return 1;
    };
    switch (command) {
        .init => try commands.init(),
        .@"cat-file" => |opts| try commands.catFile(opts),
        .help => |msg| {
            try stdout.print("{s}", .{msg});
            try stdout.flush();
        },
        else => {},
    }

    return 0;
}
