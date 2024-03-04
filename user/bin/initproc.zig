const std = @import("std");
const shared = @import("shared");
const process = @import("../process.zig");
const console = @import("../console.zig");

export fn main() callconv(.C) i32 {
    if (process.fork() == 0) {
        const shell: [:0]const u8 = "user_shell";
        _ = process.exec(shell);
    } else {
        while (true) {
            var exit_code: i32 = 0;
            const pid = process.wait(&exit_code);
            if (pid == -1) {
                _ = process.yield();
                continue;
            } else if (pid == 1) {
                return 0;
            } else {
                console.stdout.info(
                    "[initproc] Released a zombie process, pid={d}, exit_code={d}",
                    .{pid, exit_code}
                );
            }
        }
    }
    return 0;
}
