const shared = @import("shared");
const console = @import("../console.zig");
const mm = @import("../mm/lib.zig");
const addr = mm.address;
const manager = @import("manager.zig");
const trap = @import("../trap/lib.zig");
const timer = @import("../timer.zig");

const TaskContext = @import("context.zig").TaskContext;
const TaskStatus = @import("task.zig").TaskStatus;
const TaskControlBlock = @import("task.zig").TaskControlBlock;

const MapPermission = mm.memory_set.MapPermission;
const MapPermissions = mm.memory_set.MapPermissions;

extern fn __switch(curr_ctx_ptr: *TaskContext, next_ctx_ptr: *const TaskContext) callconv(.C) void;

pub const Processor = struct {
    current: ?*TaskControlBlock,
    idle_task_ctx: TaskContext,

    const Self = @This();
    pub fn init() Self {
        return Self {
            .current = null,
            .idle_task_ctx = TaskContext.zero(),
        };
    }

    pub fn take_current(self: *Self) ?*TaskControlBlock {
        const ptr = self.current orelse return null;
        self.current = null;
        return ptr;
    }

    pub fn get_current(self: *Self) ?*TaskControlBlock {
        return self.current;
    }

    fn current_task_mmap(self: *Self, start_va: addr.VirtAddr, end_va: addr.VirtAddr, perms: MapPermissions) !void {
        try self.current
            .?
            .mem_set
            .insert_framed_area(start_va, end_va, perms);
    }

    fn current_task_munmap(self: *Self, start_va: addr.VirtAddr, end_va: addr.VirtAddr) !void {
        try self.current
            .?
            .mem_set
            .remove(start_va, end_va);
    }
};

var PROCESSOR: Processor = Processor.init();

pub fn run_tasks() void {
    while (true) {
        if (manager.fetch_task()) |task| {
            const idle_task_ctx_ptr = &PROCESSOR.idle_task_ctx;
            const next_ctx_ptr = &task.ctx;
            task.status = TaskStatus.Running;
            task.get_scheduled();
            PROCESSOR.current = task;
            __switch(idle_task_ctx_ptr, next_ctx_ptr);
        }
    }
}

pub fn take_current_task() ?*TaskControlBlock {
    return PROCESSOR.take_current();
}

pub fn current_user_token() usize {
    return current_task().?.get_user_token();
}

pub fn current_task() ?*TaskControlBlock {
    return PROCESSOR.get_current();
}

pub fn current_trap_ctx() *trap.TrapContext {
    return current_task().?.get_trap_ctx();
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
    try PROCESSOR.current_task_mmap(start_va, end_va, permissions);
}

pub fn current_task_munmap(start: usize, end: usize) !void {
    const start_va = addr.VirtAddr.from(start);
    const end_va = addr.VirtAddr.from(end);
    try PROCESSOR.current_task_munmap(start_va, end_va);
}

pub fn check_addr(p: usize) void {
    const cur = PROCESSOR.current.?;
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

pub fn schedule(switched_task_ctx_ptr: *TaskContext) void {
    const idle_task_ctx_ptr = &PROCESSOR.idle_task_ctx;
    __switch(switched_task_ctx_ptr, idle_task_ctx_ptr);
}
