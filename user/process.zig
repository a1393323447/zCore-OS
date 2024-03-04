// TODO: 抽象一个 zcore-lib

const syscall = @import("syscall.zig");

pub fn read(fd: usize, buf: []u8) isize {
    return syscall.sys_read(fd, buf);
}

pub fn write(fd: usize, buf: []const u8) isize {
    return syscall.sys_write(fd, buf);
}

pub fn getpid() isize {
    return syscall.sys_getpid();
}

pub fn yield() isize {
    return syscall.sys_yield();
}

pub fn exit(code: i32) noreturn {
    syscall.sys_exit(code);
}

pub fn set_priority(prio: usize) void {
    _ = syscall.sys_set_priority(prio);
}

pub fn fork() isize {
    return syscall.sys_fork();
}

pub fn exec(path: []const u8) isize {
    return syscall.sys_exec(path);
}

pub fn spawn(path: []const u8) isize {
    return syscall.sys_spawn(path);
}

pub fn waitpid(pid: usize, exit_code: *i32) isize {
    while (true) {
        switch (syscall.sys_waitpid(@bitCast(pid), exit_code)) {
            -2 => { _ = syscall.sys_yield(); },
            else => |n| return n,
        }
    }
}

pub fn wait(exit_code: *i32) isize {
    while (true) {
        switch (syscall.sys_waitpid(-1, exit_code)) {
            -2 => { _ = syscall.sys_yield(); },
            else => |n| return n,
        }
    }
}

pub fn wait_debug(exit_code: *i32, yield_cnt: *usize) isize {
    while (true) {
        switch (syscall.sys_waitpid(-1, exit_code)) {
            -2 => {
                yield_cnt.* += 1;
                _ = syscall.sys_yield();
            },
            else => |n| return n,
        }
    }
}

pub fn mmap(start: usize, len: usize, prot: usize) isize {
    return syscall.sys_mmap(start, len, prot);
}

pub fn munmap(start: usize, len: usize) isize {
    return syscall.sys_munmap(start, len);
}
