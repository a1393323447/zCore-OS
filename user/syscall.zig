const SYSCALL_WRITE: usize = 64;
const SYSCALL_EXIT: usize = 93;
const SYSCALL_YIELD: usize = 124;
const SYSCALL_GET_TIME: usize = 169;

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
