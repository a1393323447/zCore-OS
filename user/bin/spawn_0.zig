const console = @import("../console.zig");
const process = @import("../process.zig");

const MAX_CHILD: usize = 40;

export fn main() callconv(.C) i32 {
    for (0..MAX_CHILD) |_| {
        const pid = process.spawn("test_getpid\x00");
        if (pid <= 0) {
            console.stdout.err("err: pid {d}", .{pid});
            return -1;
        } else {
            console.stdout.info("new child {d}", .{pid});
        }
    }

    var exit_code: i32 = 0;
    for (0..MAX_CHILD) |_| {
        if (process.wait(&exit_code) <= 0) {
            console.stdout.err("Wait stop early", .{});
            return -1;
        }
        if (exit_code != 0) {
            console.stdout.err("error exit code {d}", .{exit_code});
            return -1;
        }
    }

    if (process.wait(&exit_code) > 0) {
        console.stdout.err("wait got to many", .{});
        return -1;
    }

    console.stdout.info("spawn_0 passed", .{});
    return 0;
}
