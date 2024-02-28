const std = @import("std");
const mm = @import("../mm/lib.zig");
const task = @import("../task/lib.zig");
const panic = @import("../panic.zig");
const console = @import("../console.zig");
const assert = @import("../assert.zig");
const riscv = @import("../riscv/lib.zig");

const FD_STDIN: usize = 0;
const FD_STDOUT: usize = 1;

/// write buf of length `len` to a file with `fd`
pub fn sys_write(fd: usize, ptr: [*]const u8, len: usize) isize {
    switch (fd) {
        FD_STDOUT => {
            // 注意! 在虚拟内存中连续的空间, 在物理内存里不一定连续
            const bufs = mm.page_table.translated_byte_buffer(
                task.current_user_token(), 
                ptr, 
                len, 
                mm.heap_allocator.allocator
            ) catch |e| panic.panic("Failed to translate buffer: {}", .{e});
            defer bufs.deinit();
            for (bufs.items) |buf| {
                console.logger.print("{s}", .{buf});
            }
            return @intCast(len);
        },
        else => {
            panic.panic("Unsupported fd in sys_write!", .{});
        },
    }
}

pub fn sys_read(fd: usize, buf: [*]const u8, len: usize) isize {
    switch (fd) {
        FD_STDIN => {
            assert.assert_eq(len, 1, @src());
            var c: usize = undefined;
            while (true) {
                c = riscv.sbi.console_getchar();
                if (c == 0) {
                    task.suspend_current_and_run_next();
                } else {
                    break;
                }
            }
            const ch: u8 = @truncate(c);
            const buffers = mm.page_table.translated_byte_buffer(
                task.current_user_token(),
                buf,
                len, 
                mm.heap_allocator.allocator,
            ) catch |e| panic.panic("Failed to translate buffer: {}", .{e});
            defer buffers.deinit();
            buffers.items[0][0] = ch;
            return 1;
        },
        else => {
            panic.panic("Unsupported fd {d} in sys_read!", .{fd});
        }
    }
}

