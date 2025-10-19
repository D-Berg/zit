const std = @import("std");
const cli = @import("cli.zig");
const assert = std.debug.assert;

var stdout_buf: [64]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_writer.interface;

var stderr_buf: [64]u8 = undefined;
var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
const stderr = &stderr_writer.interface;

pub fn init() !void {
    try std.fs.cwd().makePath(".git/objects");
    try std.fs.cwd().makePath(".git/refs");

    var git_dir = try std.fs.cwd().openDir(".git", .{});
    defer git_dir.close();

    const head = try git_dir.createFile("HEAD", .{});
    defer head.close();

    var file_buf: [64]u8 = undefined;
    var fw = head.writer(&file_buf);
    try fw.interface.print("ref: refs/heads/main\n", .{});
    try fw.interface.flush();

    try stdout.print("Initialized git directory", .{});
}

pub fn catFile(opts: cli.CatFile) !void {
    var object_dir = std.fs.cwd().openDir(".git/objects", .{}) catch |err| {
        try stderr.print("fatal: failed to open dir .git/objects", .{});
        try stderr.flush();
        return err;
    };
    defer object_dir.close();

    var hash_dir = object_dir.openDir(opts.object[0..2], .{ .iterate = true }) catch |err| {
        try stderr.print("fatal: failed to open objects/{s}", .{opts.object[0..2]});
        try stderr.flush();
        return err;
    };
    defer hash_dir.close();

    const object_file = object_file: {
        if (opts.object.len == 40) break :object_file hash_dir.openFile(opts.object[2..], .{});
        if (opts.object.len >= 6) {
            var it = hash_dir.iterate();
            while (try it.next()) |entry| {
                switch (entry.kind) {
                    .file => {
                        if (std.mem.startsWith(u8, entry.name, opts.object[2..])) {
                            break :object_file try hash_dir.openFile(entry.name, .{});
                        }
                    },
                    else => continue,
                }
            }
        }
        break :object_file error.FileNotFound;
    } catch |err| {
        try stderr.print("fatal: failed to open {s}", .{opts.object[2..]});
        try stderr.flush();
        return err;
    };
    defer object_file.close();

    var read_buf: [1024]u8 = undefined;
    var file_reader = object_file.reader(&read_buf);
    const fr = &file_reader.interface;

    var decompress_buf: [std.compress.flate.max_window_len]u8 = undefined;
    var decompressor = std.compress.flate.Decompress.init(fr, .zlib, &decompress_buf);

    // kind
    _ = try decompressor.reader.takeDelimiter(' ') orelse return error.MissingObjectType;

    const len_str = try decompressor.reader.takeDelimiter(0) orelse return error.MissingObjectType;
    const len = try std.fmt.parseInt(usize, len_str, 10);

    try decompressor.reader.streamExact(stdout, len);
    try stdout.flush();
}
