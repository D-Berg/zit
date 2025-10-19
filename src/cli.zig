const std = @import("std");
const build_options = @import("build_options");
const assert = std.debug.assert;

pub const Command = union(enum) {
    init,
    @"cat-file": CatFile,

    @"--help",
    @"-h",
    help: []const u8,

    @"-v",
    @"--version",
    version,

    @"hash-object": HashObject,
};

pub const CatFile = struct {
    pritty_print: bool = false,
    object: []const u8,
};

pub const HashObject = struct {
    write: bool = false,
    file_path: []const u8 = "",
};

pub const ParseError = error{
    NoArgs,
    MissingArg,
    UnsupportedCommand,
};

const usage_str =
    \\Usage: git-starter-rust <COMMAND>
    \\
    \\Commands:
    \\  init           Create an empty Git repository or reinitialize an existing one
    \\  cat-file     
    \\  hash-object  
    \\  help           Print this message or the help of the given subcommand(s)
    \\
    \\Options:
    \\  -h, --help     Print help information
    \\  -v, --version  Print version information
    \\
;

pub fn parseCommands(args: *std.process.ArgIterator, err_out: *std.Io.Writer) !Command {
    assert(args.skip());

    var stdout_buf: [64]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

    if (args.next()) |cmd_str| {
        if (std.meta.stringToEnum(std.meta.FieldEnum(Command), cmd_str)) |cmd| {
            switch (cmd) {
                .init => return .init,
                .@"cat-file" => return try parseCatFile(args, err_out),

                .@"-h",
                .@"--help",
                .help,
                => return .{ .help = usage_str },

                .@"-v",
                .@"--version",
                .version,
                => {
                    try stdout.print("zit version {s}\n", .{build_options.version});
                    try stdout.flush();
                    return .version;
                },

                .@"hash-object" => return try parseHashObject(args, err_out),
            }
        }

        try err_out.print("unknown option: {s}\n", .{cmd_str});
        try err_out.flush();
        return error.UnsupportedCommand;
    }

    return .{ .help = usage_str };
}

pub fn parseCatFile(args: *std.process.ArgIterator, err_out: *std.Io.Writer) !Command {
    if (args.next()) |option| {
        const object = args.next() orelse {
            try err_out.print("fatal: only two arguments allowed in <type> <object> mode, not 1", .{});
            try err_out.flush();
            return error.MissingArg;
        };
        if (std.mem.eql(u8, option, "-p")) {
            return .{ .@"cat-file" = .{ .object = object, .pritty_print = true } };
        }

        try err_out.print("cat-file currently do not support other options", .{});
        try err_out.flush();
        return error.WrongArg;
    }

    try err_out.print("you must supply more args", .{});
    try err_out.flush();
    return error.MissingArg;
}

pub fn parseHashObject(args: *std.process.ArgIterator, err_out: *std.Io.Writer) !Command {
    var hash_obj: HashObject = .{};
    if (args.next()) |option| {
        if (std.mem.eql(u8, option, "-w")) {
            hash_obj.write = true;
            hash_obj.file_path = args.next() orelse return error.MissingArg;
            return .{ .@"hash-object" = hash_obj };
        }

        if (std.mem.startsWith(u8, option, "-")) return error.UnsupportedCommand;

        hash_obj.file_path = option;
        return .{ .@"hash-object" = hash_obj };
    }

    try err_out.print("you must supply more args", .{});
    try err_out.flush();
    return error.MissingArg;
}
