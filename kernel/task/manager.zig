const std = @import("std");
const shared = @import("shared");
const panic = @import("../panic.zig");

const Dequeue = shared.utils.Dequeue;
const TaskControlBlock = @import("task.zig").TaskControlBlock;

pub const TaskManager = struct {
    const TaskQueue = Dequeue(*TaskControlBlock);

    ready_queue: TaskQueue,

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self {
            .ready_queue = try TaskQueue.init(allocator),
        };
    }

    pub fn deinit(self: *Self) Self {
        self.ready_queue.deinit();
    }

    pub fn add(self: *Self, task: *TaskControlBlock) !void {
        try self.ready_queue.pushBack(task);
    }

    pub fn fetch(self: *Self) ?*TaskControlBlock {
        return self.ready_queue.popFront();
    }
};

var MANAGER_LOCK = shared.lock.SpinLock.init();
var TASK_MANAGER: TaskManager = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    TASK_MANAGER = TaskManager.init(allocator)
        catch |e| panic.panic("Failed to init task manager due to {}", .{e});
}

pub fn add_task(task: *TaskControlBlock) void {
    MANAGER_LOCK.acquire();
    defer MANAGER_LOCK.release();
    TASK_MANAGER.add(task) 
        catch |e| panic.panic("Failed to add task due to {}", .{e});
}

pub fn fetch_task() ?*TaskControlBlock {
    MANAGER_LOCK.acquire();
    defer MANAGER_LOCK.release();
    return TASK_MANAGER.fetch();
}
