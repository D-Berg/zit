const std = @import("std");
const assert = std.debug.assert;

pub const Command = union(enum) {
    init,
    @"cat-file",
};

pub const ParseError = error{
    NoArgs,
};

pub fn parseCommands(args: *std.process.ArgIterator) !Command {
    assert(args.skip());

    if (args.next()) |cmd_str| {
        if (std.meta.stringToEnum(std.meta.FieldEnum(Command), cmd_str)) |cmd| {
            switch (cmd) {
                .init => return .init,
                .@"cat-file" => return .@"cat-file",
            }
        }
    }

    return error.NoArgs;
}
