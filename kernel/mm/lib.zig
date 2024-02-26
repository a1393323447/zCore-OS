pub const address = @import("address.zig");
pub const memory_set = @import("memory_set.zig");
pub const page_table = @import("page_table.zig");
pub const frame_allocator = @import("frame_allocator.zig");
pub const heap_allocator = @import("heap_allocator.zig");

pub const remap_test = memory_set.remap_test;

pub fn init() void {
    heap_allocator.init_heap();
    frame_allocator.init_frame_allocator(heap_allocator.allocator);
    memory_set.init_kernel_space(heap_allocator.allocator);
}
