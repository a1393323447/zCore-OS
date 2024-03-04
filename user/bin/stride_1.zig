const console = @import("../console.zig");
const process = @import("../process.zig");
const syscall = @import("../syscall.zig");

fn spin_delay() void {
    var i: bool = true;
    var pi: *volatile bool = &i;
    for (0..10) |_| {
        pi.* = !pi.*;
    }
}

fn count_during(prio: usize) usize {
    const start_time = syscall.sys_get_time();
    process.set_priority(prio);
    var acc: usize = 0;
    while (true) {
        spin_delay();
        acc += 1;
        if (acc % 400 == 0) {
            const time = syscall.sys_get_time() - start_time;
            if (time > 1000) {
                return acc;
            }
        }
    }
}

export fn main() callconv(.C) i32 {
    const prio = 1;
    const count = count_during(1);
    console.stdout.info("priority = {d}, count = {d}", .{prio, count});
    return 0;
}