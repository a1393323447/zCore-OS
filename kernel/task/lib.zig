const std = @import("std");
const panic = @import("../panic.zig");
const loader = @import("../loader.zig");
const console = @import("../console.zig");
const trap = @import("../trap/lib.zig");
const pid = @import("pid.zig");
const processor = @import("processor.zig");
pub const manager = @import("manager.zig");

const TaskContext = @import("context.zig").TaskContext;
const TaskControlBlock = @import("task.zig").TaskControlBlock;

pub const take_current_task = processor.take_current_task;
pub const current_user_token = processor.current_user_token;
pub const current_task = processor.current_task;
pub const current_trap_ctx = processor.current_trap_ctx;
pub const current_task_mmap = processor.current_task_mmap;
pub const current_task_munmap = processor.current_task_munmap;
pub const check_addr = processor.check_addr;
pub const run_tasks = processor.run_tasks;

pub fn init(allocator: std.mem.Allocator) void {
    pid.init(allocator);
    manager.init(allocator);
    init_initproc(allocator) 
        catch |e| panic.panic("Failed to init initproc: {}", .{e});
    add_initproc();
}

/// suspend current task, then run next task
pub fn suspend_current_and_run_next() void {
    // There must be an application running.
    const task = take_current_task().?;
    const task_ctx_ptr = &task.ctx;
    task.status = .Ready;
    task.end_scheduled();

    manager.add_task(task);
    processor.schedule(task_ctx_ptr);
}

/// exit current task,  then run next task
pub fn exit_current_and_run_next(exit_code: i32) void {
    const task = take_current_task().?;
    task.status = .Zombie;
    task.exit_code = exit_code;

    for (task.children.items) |child| {
        child.parent = INITPROC;
        INITPROC.children.append(child)
            catch |e| panic.panic("Failed to recycle child process: {}", .{e});
    }

    task.children.items.len = 0;
    task.mem_set.recycle_data_pages();

    // we do not have to save task context
    var _unused = TaskContext.zero();
    processor.schedule(&_unused);
}

var INITPROC: *TaskControlBlock = undefined;

pub fn init_initproc(allocator: std.mem.Allocator) !void {
    INITPROC = try allocator.create(TaskControlBlock);
    INITPROC.* = try TaskControlBlock.new(
        allocator,
        loader.get_app_data_by_name("initproc") orelse return error.InitProcNotFound
    );
}

pub fn create_task(path: []const u8, allocator: std.mem.Allocator) !*TaskControlBlock {
    const new_task = try allocator.create(TaskControlBlock);
    new_task.* = try TaskControlBlock.new(
        allocator,
        loader.get_app_data_by_name(path) orelse return error.ProcNotFound
    );
    return new_task;
}

pub fn add_initproc() void {
    manager.add_task(INITPROC);
}
