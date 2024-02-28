const std = @import("std");
const syscall = @import("syscall.zig");

extern fn main() callconv(.C) i32;

export fn _start() linksection(".text.entry") callconv(.C) noreturn {
    syscall.sys_exit(main());
}

