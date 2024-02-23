const std = @import("std");
const shared = @import("shared");
const buddy = @import("../buddy2.zig");
const config = @import("../config.zig");

var HEAP_SPACE: [config.KERNEL_HEAP_SIZE]u8 = 
[_] u8 { 0 } ** config.KERNEL_HEAP_SIZE;

var HEAP_LOCK = shared.lock.SpinLock.init();
var HEAP_ALLOCATOR: buddy.Buddy2Allocator = undefined;
pub var allocator: std.mem.Allocator = undefined;

pub fn init_heap() void {
    HEAP_ALLOCATOR = buddy.Buddy2Allocator.init(&HEAP_SPACE);
    allocator = HEAP_ALLOCATOR.allocator();
}

// TODO: 不知道为什么 buddy 放在 shared 里会出错, 只能放在 kernel 里
