const console = @import("../console.zig");
const process = @import("../process.zig");

const MAX_CHILD: usize = 40;

export fn main() callconv(.C) i32 {
    for (0..MAX_CHILD) |i| {
        const pid = process.fork();
        if (pid == 0) {
            console.stdout.print("I am child {d}\n", .{i});
            process.exit(0);
        } else {
            console.stdout.print("forked child pid {d}\n", .{pid});
        }
        if (pid <= 0) {
            console.stdout.err("err: pid {d}", .{pid});
            return -1;
        }
    }

    var exit_code: i32 = 0;
    for (0..MAX_CHILD) |_| {
        if (process.wait(&exit_code) <= 0) {
            console.stdout.err("Wait stop early", .{});
            return -1;
        }
    }

    if (process.wait(&exit_code) > 0) {
        console.stdout.err("wait got to many", .{});
        return -1;
    }

    console.stdout.info("forktest_0 passed", .{});
    return 0;
}
