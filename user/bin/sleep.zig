const console = @import("../console.zig");
const syscall = @import("../syscall.zig");

export fn main() callconv(.C) i32 {
    const cur_time = syscall.sys_get_time();
    const wait_for = cur_time + 3000;
    while (syscall.sys_get_time() < wait_for) {
        _ = syscall.sys_yield();
    }
    console.stdout.print("Test sleep OK!\n", .{});
    return 0;
}