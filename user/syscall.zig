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

inline fn syscall(id: usize, args: [3]usize) isize {
    return asm volatile ("ecall"
        : [ret] "={x10}" (-> isize),
        : [arg0] "{x10}" (args[0]),
          [arg1] "{x11}" (args[1]),
          [arg2] "{x12}" (args[2]),
          [id] "{x17}" (id),
    );
}

pub inline fn sys_write(fd: usize, buf: []const u8) isize {
    const buf_addr = @intFromPtr(buf.ptr);
    const args = [3]usize{ fd, buf_addr, buf.len };
    return syscall(SYSCALL_WRITE, args);
}

pub inline fn sys_exit(exit_code: i32) isize {
    const args = [3]usize{ @intCast(exit_code), 0, 0 };
    return syscall(SYSCALL_EXIT, args);
}

pub inline fn sys_yield() isize {
    return syscall(SYSCALL_YIELD, [_]usize{0, 0, 0});
}

pub fn sys_get_time() isize {
    return syscall(SYSCALL_GET_TIME, [_]usize{0, 0, 0});
}

pub fn sys_mmap(start: usize, len: usize, prot: usize) isize {
    return syscall(SYSCALL_MMAP, [_]usize{start, len, prot});
}

pub fn sys_munmap(start: usize, len: usize) isize {
    return syscall(SYSCALL_MUNMAP, [_]usize{start, len, 0});
}
