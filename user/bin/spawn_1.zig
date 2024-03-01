const console = @import("../console.zig");
const process = @import("../process.zig");

const MAX_CHILD: usize = 40;

export fn main() callconv(.C) i32 {
    for (0..MAX_CHILD) |_| {
        const pid = process.spawn("sleep\x00");
        if (pid <= 0) {
            console.stdout.err("err: pid {d}", .{pid});
            return -1;
        } else {
            console.stdout.info("new child {d}", .{pid});
        }
    }

    var yield_cnt: usize = 0;
    var exit_code: i32 = 0;
    for (0..MAX_CHILD) |_| {
        if (process.wait_debug(&exit_code, &yield_cnt) <= 0) {
            console.stdout.err("Wait stop early", .{});
            return -1;
        }
        if (exit_code != 0) {
            console.stdout.err("error exit code {d}", .{exit_code});
            return -1;
        }
    }

    if (process.wait_debug(&exit_code, &yield_cnt) > 0) {
        console.stdout.err("wait got to many", .{});
        return -1;
    }

    console.stdout.info("spawn_0 passed", .{});
    console.stdout.info("Total sys_yield call {d}", .{yield_cnt});
    return 0;
}
