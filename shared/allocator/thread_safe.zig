const std = @import("std");

const SpinLock = @import("../lock.zig").SpinLock;

pub fn ThreadSafe(comptime Allocator: type) type {
    return struct {
        raw: Allocator,
        lock: SpinLock,
        vtable: *const std.mem.Allocator.VTable,

        const Self = @This();
        pub fn init(not_thread_safe: Allocator) Self {
            var mut_alloc = not_thread_safe;
            return Self {
                .raw = mut_alloc,
                .lock = SpinLock.init(),
                .vtable = mut_alloc.allocator().vtable,
            };
        }

        pub fn allocator(self: *Self) std.mem.Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                },
            };
        }

        fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ctx));
            self.lock.acquire();
            defer self.lock.release();
            return self.vtable.alloc(&self.raw, len, ptr_align, ret_addr);
        }

        fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
            const self: *Self = @ptrCast(@alignCast(ctx));
            self.lock.acquire();
            defer self.lock.release();
            return self.vtable.resize(&self.raw, buf, buf_align, new_len, ret_addr);
        }

        fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
            const self: *Self = @ptrCast(@alignCast(ctx));
            self.lock.acquire();
            defer self.lock.release();
            self.vtable.free(&self.raw, buf, buf_align, ret_addr);
        }
    };
}
