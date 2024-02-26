const std = @import("std");
const panic = @import("../panic.zig");
const riscv = @import("../riscv/lib.zig");
const config = @import("../config.zig");
const loader = @import("../loader.zig");
const console = @import("../console.zig");
const timer = @import("../timer.zig");
const task = @import("task.zig");
const trap = @import("../trap/lib.zig");
const mm = @import("../mm/lib.zig");
const addr = mm.address;

const SpinLock = @import("shared").lock.SpinLock;
const ArrayList = std.ArrayList;

const MapPermission = mm.memory_set.MapPermission;
const MapPermissions = mm.memory_set.MapPermissions;

const TaskContext = @import("context.zig").TaskContext;
const TaskStatus = task.TaskStatus;
const TaskControlBlock = task.TaskControlBlock;
pub extern fn __switch(curr_ctx_ptr: *TaskContext, next_ctx_ptr: *const TaskContext) callconv(.C) void;

pub const TaskMananger = struct {
    app_num: usize,
    cur_task: usize,
    tasks: ArrayList(TaskControlBlock),

    const Self = @This();

    fn run_first_task(self: *Self) noreturn {
        MANAGER_LOCK.acquire();
        
        const first_task = &self.tasks.items[0];
        first_task.status = TaskStatus.Running;
        const next_task_ctx_ptr = &first_task.ctx;
        
        MANAGER_LOCK.release();

        var unused = TaskContext.zero();
        
        timer.set_next_trigger();

        __switch(&unused, next_task_ctx_ptr);

        panic.panic("unreachable in run_first_task!", .{});
    }

    inline fn mark_current(self: *Self, status: TaskStatus) void {
        MANAGER_LOCK.acquire();
        defer MANAGER_LOCK.release();

        self.tasks.items[self.cur_task].status = status;
    }

    fn mark_current_suspended(self: *Self) void {
        self.mark_current(.Ready);
    }

    fn mark_current_exited(self: *Self) void {
        self.mark_current(.Exited);
    }

    fn find_next_task(self: *Self) ?usize {
        MANAGER_LOCK.acquire();
        defer MANAGER_LOCK.release();
        
        const cur = self.cur_task;
        const start = cur + 1;
        const end = start + self.app_num;
        for (start..end) |idx| {
            const id = idx % self.app_num;
            if (self.tasks.items[id].status == .Ready) {
                return id;
            }
        }

        return null;
    }

    fn get_current_token(self: *Self) usize {
        MANAGER_LOCK.acquire();
        defer MANAGER_LOCK.release();
        return self.tasks.items[self.cur_task].get_user_token();
    }

    fn get_current_trap_ctx(self: *Self) *trap.TrapContext {
        MANAGER_LOCK.acquire();
        defer MANAGER_LOCK.release();
        return self.tasks.items[self.cur_task].get_trap_ctx();
    }

    fn run_next_task(self: *Self) void {
        if (self.find_next_task()) |next| {
            MANAGER_LOCK.acquire();
            const curr = self.cur_task;
            self.tasks.items[next].status = .Running;
            self.cur_task = next;
            const curr_ctx_ptr = &self.tasks.items[curr].ctx;
            const next_ctx_ptr = &self.tasks.items[next].ctx;
            MANAGER_LOCK.release();

            timer.set_next_trigger();
            __switch(curr_ctx_ptr, next_ctx_ptr);
        } else {
            console.logger.info("All applicaions completed", .{});
            riscv.sbi.shutdown();
        }
    }

    fn current_task_mmap(self: *Self, start_va: addr.VirtAddr, end_va: addr.VirtAddr, perms: MapPermissions) !void {
        MANAGER_LOCK.acquire();
        defer MANAGER_LOCK.release();
        try self.tasks.items[self.cur_task]
            .mem_set
            .insert_framed_area(start_va, end_va, perms);
    }

    fn current_task_munmap(self: *Self, start_va: addr.VirtAddr, end_va: addr.VirtAddr) !void {
        MANAGER_LOCK.acquire();
        defer MANAGER_LOCK.release();
        try self.tasks.items[self.cur_task]
            .mem_set
            .remove(start_va, end_va);
    }
};

var TASK_MANAGER: TaskMananger = undefined;
var MANAGER_LOCK: SpinLock = SpinLock.init();

pub fn init(allocator: std.mem.Allocator) void {
    const app_num = loader.get_app_num();
    TASK_MANAGER.app_num = app_num;
    TASK_MANAGER.cur_task = 0;
    TASK_MANAGER.tasks = ArrayList(TaskControlBlock).init(allocator);
    for (0..app_num) |i| {
        const block = TaskControlBlock.new(
            allocator,
            loader.get_app_data(i),
            i,
        ) catch |e| {
            console.logger.warn("Failed to load app {d} due to {}", .{i, e});
            continue;
        };
        TASK_MANAGER.tasks.append(block) catch unreachable;
    }
    asm volatile ("sfence.vma" ::: "memory");
}

/// run first task
pub fn run_first_task() void {
    TASK_MANAGER.run_first_task();
}

/// rust next task
fn run_next_task() void {
    TASK_MANAGER.run_next_task();
}

/// suspend current task
fn mark_current_suspended() void {
    TASK_MANAGER.mark_current_suspended();
}

/// exit current task
fn mark_current_exited() void {
    TASK_MANAGER.mark_current_exited();
}

/// suspend current task, then run next task
pub fn suspend_current_and_run_next() void {
    mark_current_suspended();
    run_next_task();
}

/// exit current task,  then run next task
pub fn exit_current_and_run_next() void {
    mark_current_exited();
    run_next_task();
}

pub fn current_user_token() usize {
    return TASK_MANAGER.get_current_token();
}

pub fn current_trap_ctx() *trap.TrapContext {
    return TASK_MANAGER.get_current_trap_ctx();
}

pub fn current_task_mmap(start: usize, end: usize, pert: usize) !void {
    const start_va = addr.VirtAddr.from(start);
    const end_va = addr.VirtAddr.from(end);
    var permissions = MapPermissions.empty().set(MapPermission.U);
    if (pert & (1 << 0) != 0) {
        permissions = permissions.set(MapPermission.R);
    }
    if (pert & (1 << 1) != 0) {
        permissions = permissions.set(MapPermission.W);
    }
    if (pert & (1 << 2) != 0) {
        permissions = permissions.set(MapPermission.X);
    }
    try TASK_MANAGER.current_task_mmap(start_va, end_va, permissions);
}

pub fn current_task_munmap(start: usize, end: usize) !void {
    const start_va = addr.VirtAddr.from(start);
    const end_va = addr.VirtAddr.from(end);
    try TASK_MANAGER.current_task_munmap(start_va, end_va);
}

pub fn check_addr(p: usize) void {
    const cur = &TASK_MANAGER.tasks.items[TASK_MANAGER.cur_task];
    const pte = cur.mem_set.translate(addr.VirtAddr.from(p).floor());
    if (pte) |pp| {
        console.logger.debug("pte for 0x{x} r:{}, w:{}, x:{}, v:{}", .{
            p,
            pp.is_readable(),
            pp.is_writable(),
            pp.is_executable(),
            pp.is_valid(),
        });
    } else {
        console.logger.debug("pte for 0x{x} is null", .{p});
    }
}
