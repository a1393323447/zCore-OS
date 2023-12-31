const task = @import("../task/lib.zig");
const timer = @import("../timer.zig");
const panic = @import("../panic.zig");
const console = @import("../console.zig");

/// task exits and submit an exit code
pub fn sys_exit(exit_code: i32) noreturn {
    console.logger.info("[kernel] Application exited with code {d}", .{exit_code});
    task.exit_current_and_run_next();
    panic.panic("Unreachale in sys_exit!", .{});
}

/// current task gives up resources for other tasks
pub fn sys_yield() isize {
    task.suspend_current_and_run_next();
    return 0;
}

/// get time in milliseconds
pub fn sys_get_time() isize {
    return @intCast(timer.get_time_ms());
}
