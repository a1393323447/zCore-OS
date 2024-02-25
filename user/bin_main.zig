const std = @import("std");
const syscall = @import("syscall.zig");
const console = @import("console.zig");

extern fn main() callconv(.C) i32;

export fn _start() linksection(".text.entry") callconv(.C) noreturn {
    asm volatile ("li a0, 0xdeadbeef");
    asm volatile ("wfi");
    asm volatile ("wfi");
    _ = syscall.sys_exit(main());
    unreachable;
}

