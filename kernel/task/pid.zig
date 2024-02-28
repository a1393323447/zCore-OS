const std = @import("std");
const shared = @import("shared");
const assert = @import("../assert.zig");
const console = @import("../console.zig");
const config = @import("../config.zig");
const panic = @import("../panic.zig");
const mm = @import("../mm/lib.zig");
const addr = mm.address;

const ArrayList = std.ArrayList;
const SpinLock = shared.lock.SpinLock;
const MapPermission = mm.memory_set.MapPermission;
const MapPermissions = mm.memory_set.MapPermissions;

pub const PidHandle = struct {
    v: usize,

    const Self = @This();

    pub fn init(pid: usize) Self {
        return PidHandle { .v = pid };
    }

    pub fn deinit(self: *const Self) void {
        pid_dealloc(self.v);
    }
};

const PidAllocator = struct {
    current: usize,
    recycled: ArrayList(usize),

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self {
            .current = 0,
            .recycled = ArrayList(usize).init(allocator),
        };
    }

    pub fn alloc(self: *Self) PidHandle {
        if (self.recycled.popOrNull()) |pid| {
            return PidHandle.init(pid);
        } else {
            self.current += 1;
            return PidHandle.init(self.current - 1);
        }
    }

    pub fn dealloc(self: *Self, pid: usize) void {
        assert.assert(
            pid < self.current,
            "pid({d}) >= current({d})",
            .{pid, self.current}
        );
        for (self.recycled.items) |recycled_pid| {
            assert.assert(
                recycled_pid != pid,
                "pid {} has been deallocated!",
                .{pid}
            );
        }
        self.recycled.append(pid) catch unreachable;
    }

    pub fn deinit(self: *const Self) void {
        self.recycled.deinit();
    }
};

var PID_ALLOC_LOCK = SpinLock.init();
var PID_ALLOCATOR: PidAllocator = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    PID_ALLOCATOR = PidAllocator.init(allocator);
}

pub fn pid_alloc() PidHandle {
    PID_ALLOC_LOCK.acquire();
    defer PID_ALLOC_LOCK.release();

    return PID_ALLOCATOR.alloc();
}

fn pid_dealloc(pid: usize) void {
    PID_ALLOC_LOCK.acquire();
    defer PID_ALLOC_LOCK.release();

    PID_ALLOCATOR.dealloc(pid);
}


pub const StackInfo = struct {
    top: usize,
    bottom: usize,
};

/// Return (bottom, top) of a kernel stack in kernel space.
pub fn kernel_stack_position(app_id: usize) StackInfo {
    const top = config.TRAMPOLINE - app_id * (config.KERNEL_STACK_SIZE + config.PAGE_SIZE);
    const bottom = top - config.KERNEL_STACK_SIZE;
    return StackInfo {
        .top = top,
        .bottom = bottom,
    };
}

pub const KernelStack = struct {
    pid: usize,

    const Self = @This();
    pub fn init(pid_hd: PidHandle) Self {
        const pid = pid_hd.v;
        const kernel_stack = kernel_stack_position(pid);
        mm.memory_set.kernel_space_insert_framed_area(
            addr.VirtAddr.from(kernel_stack.bottom),
            addr.VirtAddr.from(kernel_stack.top),
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.W),
        ) catch |e| panic.panic("Failed to map kernel stack due to {}", .{e});
        return Self {
            .pid = pid,
        };
    }

    pub fn deinit(self: *const Self) void {
        const kernel_stack = kernel_stack_position(self.pid);
        const bottom_va = addr.VirtAddr.from(kernel_stack.bottom);
        const bottom_vpn = addr.VirtPageNum.from_addr(bottom_va);
        mm.memory_set
            .kernel_space_remove_area_with_start_vpn(bottom_vpn);
    }

    pub fn get_info(self: *const Self) StackInfo {
        return kernel_stack_position(self.pid);
    }
};

