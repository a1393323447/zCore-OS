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

pub fn sys_mmap(start: usize, len: usize, prot: usize) isize {
    if (len == 0 or len % 4096 != 0) return -1;
    task.current_task_mmap(start, start + len, prot) catch return -1;
    return 0;
}

pub fn sys_munmap(start: usize, len: usize) isize {
    if (len == 0 or len % 4096 != 0) return -1;
    task.current_task_munmap(start, start + len) catch return -1;
    return 0;
}
