const TaskContext = @import("context.zig").TaskContext;

pub extern fn __switch(curr_ctx_ptr: *TaskContext, next_ctx_ptr: *TaskContext) callconv(.C) noreturn;
