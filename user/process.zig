// TODO: 抽象一个 zcore-lib

const syscall = @import("syscall.zig");

pub fn mmap(start: usize, len: usize, prot: usize) isize {
    return syscall.sys_mmap(start, len, prot);
}
