const SpinLock = @import("shared").lock.SpinLock;

const panic = @import("../panic.zig");
const riscv = @import("../riscv/lib.zig");
const config = @import("../config.zig");
const loader = @import("../loader.zig");
const console = @import("../console.zig");
const timer = @import("../timer.zig");

const TaskContext = @import("context.zig").TaskContext;
pub extern fn __switch(curr_ctx_ptr: *TaskContext, next_ctx_ptr: *TaskContext) callconv(.C) void;

pub const TaskStatus = enum {
    UnInit,
    Ready,
    Running,
    Exited,
};

pub const TaskControlBlock = struct {
    status: TaskStatus,
    ctx: TaskContext,

    const Self = @This();

    pub fn init() Self {
        return TaskControlBlock {
            .status = TaskStatus.UnInit,
            .ctx = TaskContext.zero(),
        };
    }
};

pub const TaskMananger = struct {
    app_num: usize,
    cur_task: usize,
    tasks: [config.MAX_APP_NUM]TaskControlBlock,

    const Self = @This();

    fn run_first_task(self: *Self) noreturn {
        MANAGER_LOCK.acquire();
        
        const first_task = &self.tasks[0];
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

        self.tasks[self.cur_task].status = status;
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
            if (self.tasks[id].status == .Ready) {
                return id;
            }
        }

        return null;
    }

    fn run_next_task(self: *Self) void {
        if (self.find_next_task()) |next| {
            MANAGER_LOCK.acquire();
            const curr = self.cur_task;
            self.tasks[next].status = .Running;
            self.cur_task = next;
            const curr_ctx_ptr = &self.tasks[curr].ctx;
            const next_ctx_ptr = &self.tasks[next].ctx;
            MANAGER_LOCK.release();

            timer.set_next_trigger();
            __switch(curr_ctx_ptr, next_ctx_ptr);
        } else {
            console.logger.info("All applicaions completed", .{});
            riscv.sbi.shutdown();
        }
    }
};

var TASK_MANAGER: TaskMananger = undefined;
var MANAGER_LOCK: SpinLock = SpinLock.init();

pub fn init() void {
    TASK_MANAGER.app_num = loader.get_app_num();
    TASK_MANAGER.cur_task = 0;
    for (&TASK_MANAGER.tasks, 0..) |*task, i| {
        task.ctx = TaskContext.goto_restore(loader.init_app_ctx(i));
        task.status = TaskStatus.Ready;
    }
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
