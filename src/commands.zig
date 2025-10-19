const std = @import("std");
const cli = @import("cli.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

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

pub fn hashObject(gpa: Allocator, opts: cli.HashObject) !void {
    var sha1 = std.crypto.hash.Sha1.init(.{});

    const in_file = try std.fs.cwd().openFile(opts.file_path, .{});
    defer in_file.close();

    var in_buf: [1024]u8 = undefined;
    var file_reader = in_file.reader(&in_buf);
    const in = &file_reader.interface;

    var wa = std.Io.Writer.Allocating.init(gpa);
    defer wa.deinit();

    const file_len = try in.streamRemaining(&wa.writer);
    var file_len_buf: [128]u8 = undefined;

    const file_len_str = try std.fmt.bufPrintZ(&file_len_buf, "{d}", .{file_len});

    sha1.update("blob ");
    sha1.update(file_len_str[0..(file_len_str.len + 1)]);
    sha1.update(wa.written());
    const hash = sha1.finalResult();

    var readable_hash_buf: [std.crypto.hash.Sha1.digest_length * 2]u8 = undefined;
    const readable_hash = try std.fmt.bufPrint(&readable_hash_buf, "{x}", .{hash[0..]});

    try stdout.print("{s}\n", .{readable_hash});
    try stdout.flush();

    if (opts.write) {
        var objects_dir = try std.fs.cwd().openDir(".git/objects", .{});
        defer objects_dir.close();

        try objects_dir.makePath(readable_hash[0..2]);

        var blob_dir = try objects_dir.openDir(readable_hash[0..2], .{});
        defer blob_dir.close();

        const obj_file = try blob_dir.createFile(readable_hash[2..], .{});
        defer obj_file.close();

        var out_buf: [1024]u8 = undefined;
        var out_writer = obj_file.writer(&out_buf);

        var compress_buf: [std.compress.flate.max_window_len]u8 = undefined;
        var compressor = try std.compress.flate.Compress.init(&out_writer.interface, &compress_buf, .zlib, .default);

        try compressor.writer.print("blob {d}", .{file_len});
        try compressor.writer.writeByte(0);

        var reader = std.Io.Reader.fixed(wa.written());

        assert(file_len == try reader.streamRemaining(&compressor.writer));
        try compressor.writer.flush();
        try out_writer.interface.flush();
    }
}
