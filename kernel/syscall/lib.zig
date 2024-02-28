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

pub const SYSCALL_OPENAT: usize = 56;
pub const SYSCALL_CLOSE: usize = 57;
pub const SYSCALL_READ: usize = 63;
pub const SYSCALL_WRITE: usize = 64;
pub const SYSCALL_UNLINKAT: usize = 35;
pub const SYSCALL_LINKAT: usize = 37;
pub const SYSCALL_FSTAT: usize = 80;
pub const SYSCALL_EXIT: usize = 93;
pub const SYSCALL_YIELD: usize = 124;
pub const SYSCALL_GET_TIME: usize = 169;
pub const SYSCALL_GET_PID: usize = 172;
pub const SYSCALL_FORK: usize = 220;
pub const SYSCALL_EXEC: usize = 221;
pub const SYSCALL_WAITPID: usize = 260;
pub const SYSCALL_SET_PRIORITY: usize = 140;
pub const SYSCALL_MUNMAP: usize = 215;
pub const SYSCALL_MMAP: usize = 222;
pub const SYSCALL_SPAWN: usize = 400;
pub const SYSCALL_MAIL_READ: usize = 401;
pub const SYSCALL_MAIL_WRITE: usize = 402;
pub const SYSCALL_DUP: usize = 24;
pub const SYSCALL_PIPE: usize = 59;

pub const fs = @import("fs.zig");
pub const process = @import("process.zig");

/// handle syscall exception with `syscall_id` and other arguments
pub fn syscall(syscall_id: usize, args: [3]usize) isize {
    return switch (syscall_id) {
        SYSCALL_READ => fs.sys_read(args[0], @ptrFromInt(args[1]), args[2]),
        SYSCALL_WRITE => fs.sys_write(args[0], @ptrFromInt(args[1]), args[2]),
        SYSCALL_EXIT => process.sys_exit(@truncate(@as(isize, @bitCast(args[0])))),
        SYSCALL_YIELD => process.sys_yield(),
        SYSCALL_GET_PID => process.sys_getpid(),
        SYSCALL_FORK => process.sys_fork(),
        SYSCALL_EXEC => process.sys_exec(@ptrFromInt(args[0])),
        SYSCALL_SPAWN => process.sys_spawn(@ptrFromInt(args[0])),
        SYSCALL_WAITPID => process.sys_waitpid(@bitCast(args[0]), @ptrFromInt(args[1])),
        SYSCALL_GET_TIME => process.sys_get_time(),
        SYSCALL_MMAP => process.sys_mmap(args[0], args[1], args[2]),
        SYSCALL_MUNMAP => process.sys_munmap(args[0], args[1]),
        else => {
            panic.panic("Unsupported syscall_id: {d}", .{syscall_id});
        },
    };
}
