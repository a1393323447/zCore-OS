const std = @import("std");
const shared = @import("shared");
const process = @import("../process.zig");
const console = @import("../console.zig");

const LF: u8 = 0x0a;
const CR: u8 = 0x0d;
const DL: u8 = 0x7f;
const BS: u8 = 0x08;

var HEAP_SPACE: [1024]u8 = 
[_] u8 { 0 } ** 1024;
var FIXED_BUF_ALLOC = std.heap.FixedBufferAllocator.init(&HEAP_SPACE);
const allocator = FIXED_BUF_ALLOC.allocator();

fn exec_cmd(path: []const u8) !i32 {
    const pid = process.fork();
    if (pid == 0) {
        // child process
        const status = process.exec(path);
        if (status == -1) {
            return error.ExecFailed;
        } else if (status == -0xef) {
            return error.NotSuchExe;
        } else {
            unreachable;
        }
    } else {
        var exit_code: i32 = 0;
        const exit_pid = process.waitpid(@bitCast(pid), &exit_code);
        if (pid != exit_pid) {
            return error.UnexpectedPid;
        } else {
            return exit_code;
        }
    }
}

export fn main() callconv(.C) i32 {
    console.stdout.print(">> ", .{});
    var line = shared.utils.String.init(allocator);
    while (true) {
        const c = console.getchar();
        switch (c) {
            LF, CR => {
                console.stdout.print("\n", .{});
                if (!line.isEmpty()) {
                    line.concat(&[_]u8{0}) catch |e| {
                        console.stdout.err("err: {}", .{e});
                        return -1;
                    };

                    const exit_code = exec_cmd(line.str()) catch |e| switch (e) {
                        error.ExecFailed => return -4,
                        error.NotSuchExe => {
                            console.stdout.err("Shell: not exe name {s}", .{line.str()});
                            line.clear();
                            console.stdout.print(">> ", .{});
                            continue;
                        },
                        error.UnexpectedPid => {
                            console.stdout.err("Shell: {}", .{e});
                            return -4;
                        }
                    };

                    console.stdout.info(
                        "Shell: process {s} exited with code {d}",
                        .{ line.str(), exit_code },
                    );

                    line.clear();
                }
                console.stdout.print(">> ", .{});
            },
            BS, DL => {
                if (!line.isEmpty()) {
                    console.stdout.print("{c} {c}", .{BS, BS});
                    _ = line.pop();
                }
            },
            else => {
                console.stdout.print("{c}", .{c});
                line.concat(&[_]u8{c}) catch |e| {
                    console.stdout.err("err: {}", .{e});
                    return -1;
                };
            }
        }
    }
}
