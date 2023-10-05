//! Implementation of syscalls
//!
//! The single entry point to all system calls, syscall, is called
//! whenever userspace wishes to perform a system call using the `ecall`
//! instruction. In this case, the processor raises an 'Environment call from
//! U-mode' exception, which is handled as one of the cases in
//! kernel.trap.trap_handler.
//!
//! For clarity, each single syscall is implemented as its own function, named
//! `sys_` then the name of the syscall. You can find functions like this in
//! submodules, and you should also implement syscalls this way.

const std = @import("std");
const panic = @import("../panic.zig");

const SYSCALL_WRITE: usize = 64;
const SYSCALL_EXIT: usize = 93;
const SYSCALL_YIELD: usize = 124;
const SYSCALL_GET_TIME: usize = 169;

pub const fs = @import("fs.zig");
pub const process = @import("process.zig");

/// handle syscall exception with `syscall_id` and other arguments
pub fn syscall(syscall_id: usize, args: [3]usize) isize {
    return switch (syscall_id) {
        SYSCALL_WRITE => fs.sys_write(args[0], @ptrFromInt(args[1]), args[2]),
        SYSCALL_EXIT => process.sys_exit(@intCast(args[0])),
        SYSCALL_YIELD => process.sys_yield(),
        SYSCALL_GET_TIME => process.sys_get_time(),
        else => {
            panic.panic("Unsupported syscall_id: {d}", .{syscall_id});
        },
    };
}
