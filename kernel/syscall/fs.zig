const std = @import("std");
const mm = @import("../mm/lib.zig");
const task = @import("../task/lib.zig");
const panic = @import("../panic.zig");
const console = @import("../console.zig");

const FD_STDOUT: usize = 1;

/// write buf of length `len` to a file with `fd`
pub fn sys_write(fd: usize, ptr: *const u8, len: usize) isize {
    switch (fd) {
        FD_STDOUT => {
            // 注意! 在虚拟内存中连续的空间, 在物理内存里不一定连续
            const bufs = mm.page_table.translated_byte_buffer(
                task.current_user_token(), 
                ptr, 
                len, 
                mm.heap_allocator.allocator
            ) catch |e| panic.panic("Failed to translate buffer due to {}", .{e});
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
