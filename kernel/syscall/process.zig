const task = @import("../task/lib.zig");
const timer = @import("../timer.zig");
const panic = @import("../panic.zig");
const loader = @import("../loader.zig");
const console = @import("../console.zig");
const mm = @import("../mm/lib.zig");
const manager = @import("../task/manager.zig");

/// task exits and submit an exit code
pub fn sys_exit(exit_code: i32) noreturn {
    task.exit_current_and_run_next(exit_code);
    panic.panic("Unreachale in sys_exit!", .{});
}

/// current task gives up resources for other tasks
pub fn sys_yield() isize {
    task.suspend_current_and_run_next();
    return 0;
}

pub fn sys_getpid() isize {
    return @intCast(task.current_task().?.pid.v);
}

pub fn sys_fork() isize {
    const cur_task = task.current_task().?;
    const new_task = cur_task.fork()
        catch |e| panic.panic("sys_fork failed: {}", .{e});
    const new_pid = new_task.pid.v;
    // modify trap context of new_task, because it returns immediately after switching
    const trap_ctx = new_task.get_trap_ctx();
    // we do not have to move to next instruction since we have done it before
    // for child process, fork returns 0
    trap_ctx.x[10] = 0;
    // add new task to scheduler
    task.manager.add_task(new_task);
    return @bitCast(new_pid);
}

pub fn sys_exec(path: [*]const u8) isize {
    const token = task.current_user_token();
    var tpath = mm.page_table.translated_str(
        token,
        path,
        mm.heap_allocator.allocator
    ) catch |e| panic.panic("Failed to translate str: {}", .{e});
    defer tpath.deinit();
    
    if (loader.get_app_data_by_name(tpath.str())) |data| {
        const cur_task = task.current_task().?;
        cur_task.exec(data)
            catch |e| panic.panic("sys_exec failed: {}", .{e});
        return 0;
    } else {
        return -1;
    }
}

pub fn sys_spawn(path: [*]const u8) isize {
    const token = task.current_user_token();
    var tpath = mm.page_table.translated_str(
        token,
        path,
        mm.heap_allocator.allocator
    ) catch |e| panic.panic("Failed to translate str: {}", .{e});
    defer tpath.deinit();
    
    const cur_task = task.current_task().?;
    const new_task = task.create_task(
        tpath.str(),
        mm.heap_allocator.allocator
    ) catch |e| switch (e) {
        error.ProcNotFound => return -1,
        else => panic.panic("Failed to exec {s}: {}", .{tpath.str(), e}),
    };
    new_task.parent = cur_task;
    cur_task.children.append(new_task) catch |e| panic.panic("Faield to add child to parent: {}", .{e});
    manager.add_task(new_task);
    return @bitCast(new_task.pid.v);
}

/// If there is not a child process whose pid is same as given, return -1.
/// Else if there is a child process but it is still running, return -2.
pub fn sys_waitpid(pid: isize, exit_code_ptr: *allowzero i32) isize {
    const upid: usize = @bitCast(pid);
    const cur_task = task.current_task().?;
    // find a child process
    var child_idx: ?usize = null;
    for (cur_task.children.items, 0..) |child, i| {
        if (child.getpid() == upid or pid == -1) {
            child_idx = i;
            break;
        }
    }

    if (child_idx) |idx| {
        var child_task = cur_task.children.items[idx];
        if (!child_task.is_zombie()) {
            cur_task.wait_for(child_task);
            return -2;
        }
        child_task = cur_task.children.orderedRemove(idx);
        const exit_code = child_task.exit_code;
        const found_pid = child_task.getpid();
        child_task.deinit();
        mm.heap_allocator.allocator.destroy(child_task);
        // now child task finished
        // we need to set the exit code to exit_code_ptr passed by parent task which is *CURRENT* task
        const trans_res = mm.page_table.translated_mut(cur_task.get_user_token(), i32, exit_code_ptr);
        if (trans_res) |ptr| {
            ptr.* = exit_code;
        } else {
            // exit_code_ptr pass by current task is invalid
            // we need to kill this task
            console.logger.warn(
                "[kernel] PageFault in application, bad memory addr = 0x{x}, bad instruction addr = 0x{x}, core dumped.", 
                .{ exit_code_ptr, cur_task.get_trap_ctx().sepc
            });
            task.exit_current_and_run_next(-1);
        }
        cur_task.stop_waiting();
        return @bitCast(found_pid);
    } else {
        return -1;
    }
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
