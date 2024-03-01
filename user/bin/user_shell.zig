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

export fn main() callconv(.C) i32 {
    console.stdout.print(">> ", .{});
    var line = shared.utils.String.init(allocator);
    while (true) {
        const c = console.getchar();
        switch (c) {
            LF, CR => {
                console.stdout.print("\n", .{});
                if (!line.isEmpty()) {
                    if (line.cmp("shutdown")) {
                        return 0;
                    }

                    line.concat(&[_]u8{0}) catch |e| {
                        console.stdout.err("err: {}", .{e});
                        return -1;
                    };

                    const pid = process.fork();
                    if (pid == 0) {
                        // child process
                        if (process.exec(line.str()) == -1) {
                            console.stdout.err("Shell: command not found: {s}", .{line.str()});
                            return -4;
                        } else {
                            console.stdout.err("unreachable in shell", .{});
                            unreachable;
                        }
                    } else {
                        var exit_code: i32 = 0;
                        const exit_pid = process.waitpid(@bitCast(pid), &exit_code);
                        if (exit_pid != pid) {
                            console.stdout.err("Shell: Unexpected pid {d}, expected {d}", .{exit_pid, pid});
                            unreachable;
                        } else {
                            console.stdout.info("Shell: {s} exited with code {d}", .{line.str(), exit_code});
                        }
                    }

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
