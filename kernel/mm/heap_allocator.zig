const std = @import("std");
const shared = @import("shared");
const config = @import("../config.zig");

const ThreadSafe = shared.allocator.ThreadSafe;
const Buddy2Allocator = shared.allocator.Buddy2Allocator;

var HEAP_SPACE: [config.KERNEL_HEAP_SIZE]u8 = 
[_] u8 { 0 } ** config.KERNEL_HEAP_SIZE;

var HEAP_LOCK = shared.lock.SpinLock.init();
var HEAP_ALLOCATOR: ThreadSafe(Buddy2Allocator) = undefined;
pub var allocator: std.mem.Allocator = undefined;

pub fn init_heap() void {
    HEAP_ALLOCATOR = ThreadSafe(Buddy2Allocator).init(Buddy2Allocator.init(&HEAP_SPACE));
    allocator = HEAP_ALLOCATOR.allocator();
}
