const std = @import("std");
const shared = @import("shared");
const config = @import("../config.zig");
const addr = @import("address.zig");
const panic = @import("../panic.zig");

const console = @import("../console.zig");

const ArrayList = std.ArrayList;

pub const FrameTracker  = struct {
    ppn: addr.PhysPageNum,

    const Self = @This();
    pub fn new(ppn: addr.PhysPageNum) Self {
        const bytes = ppn.get_bytes_array();
        @memset(bytes, 0);
        return Self { .ppn = ppn };
    }

    pub fn deinit(self: *const Self) void {
        frame_dealloc(self.ppn);
    }
};

pub const StackFrameAllocator = struct {
    current: usize,
    end: usize,
    recycled: ArrayList(usize),

    const Self = @This();
    pub fn init(l: addr.PhysPageNum, r: addr.PhysPageNum, allocator: std.mem.Allocator) Self {
        return Self {
            .current = l.v,
            .end = r.v,
            .recycled = ArrayList(usize).init(allocator),
        };
    }

    pub fn alloc(self: *Self) ?addr.PhysPageNum {
        if (self.recycled.popOrNull()) |ppn| {
            return addr.PhysPageNum.from(ppn);
        } else {
            if (self.current == self.end) {
                return null;
            } else {
                self.current += 1;
                return addr.PhysPageNum.from(self.current - 1);
            }
        }
    }

    pub fn dealloc(self: *Self, ppn: addr.PhysPageNum) void {
        if (ppn.v >= self.current) {
            panic.panic("Frame ppn = {x} has not been allocated!", .{ppn.v});
        }
        self.recycled.append(ppn.v) catch unreachable;
    }
};

var FRAME_ALLOC_LOCK = shared.lock.SpinLock.init();
var FRAME_ALLOCATOR: StackFrameAllocator = undefined;

extern fn ekernel() noreturn;

pub fn init_frame_allocator(allocator: std.mem.Allocator) void {
    const ekernel_addr = addr.PhysAddr.from(@intFromPtr(&ekernel)).ceil();
    const mem_end_addr = addr.PhysAddr.from(config.MEMORY_END).ceil();
    FRAME_ALLOCATOR = StackFrameAllocator.init(ekernel_addr, mem_end_addr, allocator);
}

pub fn frame_alloc() ?FrameTracker {
    FRAME_ALLOC_LOCK.acquire();
    defer FRAME_ALLOC_LOCK.release();
    if (FRAME_ALLOCATOR.alloc()) |ppn| {
        return FrameTracker.new(ppn);
    } else {
        return null;
    }
}

pub fn frame_dealloc(ppn: addr.PhysPageNum) void {
    FRAME_ALLOC_LOCK.acquire();
    defer FRAME_ALLOC_LOCK.release();
    FRAME_ALLOCATOR.dealloc(ppn);
}

