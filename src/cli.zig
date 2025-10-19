const std = @import("std");
const assert = std.debug.assert;

pub const Command = union(enum) {
    init,
    @"cat-file": CatFile,
    diagnostic: []const u8,
};

pub const CatFile = struct {
    pritty_print: bool = false,
    object: []const u8,
};

pub const ParseError = error{
    NoArgs,
    MissingArg,
    UnsupportedCommand,
};

pub fn parseCommands(args: *std.process.ArgIterator) !Command {
    assert(args.skip());

    if (args.next()) |cmd_str| {
        if (std.meta.stringToEnum(std.meta.FieldEnum(Command), cmd_str)) |cmd| {
            switch (cmd) {
                .init => return .init,
                .@"cat-file" => return try parseCatFile(args),
                .diagnostic => return error.UnsupportedCommand,
            }
        }
    }

    return error.NoArgs;
}

pub fn parseCatFile(args: *std.process.ArgIterator) !Command {
    if (args.next()) |option| {
        const object = args.next() orelse return .{
            .diagnostic = "fatal: only two arguments allowed in <type> <object> mode, not 1",
        };
        if (std.mem.eql(u8, option, "-p")) {
            return .{ .@"cat-file" = .{ .object = object, .pritty_print = true } };
        }

        return .{ .diagnostic = "cat-file currently do not support other options" };
    }

    return .{ .diagnostic = "you must supply more args" };
}
