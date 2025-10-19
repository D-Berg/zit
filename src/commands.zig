const std = @import("std");
pub fn init() !void {
    var stdout_buf: [64]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

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
