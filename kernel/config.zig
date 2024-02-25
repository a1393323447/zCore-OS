const std = @import("std");

pub const USER_STACK_SIZE: usize = 4096;
pub const KERNEL_STACK_SIZE: usize = 4096 * 2;
pub const KERNEL_HEAP_SIZE: usize = 0x300000;
pub const MAX_APP_NUM: usize = 4;
pub const APP_BASE_ADDRESS: usize = 0x80400000;
pub const APP_SIZE_LIMIT: usize = 0x20000;

pub const MEMORY_END: usize = 0x80f00000;
pub const PAGE_SIZE: usize = 0x1000;
pub const PAGE_SIZE_BITS: usize = 0xc;
pub const CLOCK_FREQ: usize = 12500000;

pub const TRAMPOLINE: usize = std.math.maxInt(usize) - PAGE_SIZE + 1;
pub const TRAP_CONTEXT: usize = TRAMPOLINE - PAGE_SIZE;

pub const StackInfo = struct {
    top: usize,
    bottom: usize,
};

/// Return (bottom, top) of a kernel stack in kernel space.
pub fn kernel_stack_position(app_id: usize) StackInfo {
    const top = TRAMPOLINE - app_id * (KERNEL_STACK_SIZE + PAGE_SIZE);
    const bottom = top - KERNEL_STACK_SIZE;
    return StackInfo {
        .top = top,
        .bottom = bottom,
    };
}