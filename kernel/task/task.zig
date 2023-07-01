const TaskContext = @import("context.zig").TaskContext;

pub const TaskStatus = enum {
    UnInit,
    Ready,
    Running,
    Exited,
};

pub const TaskControlBlock = struct {
    status: TaskStatus,
    ctx: TaskContext,
};
