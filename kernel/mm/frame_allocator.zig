const addr = @import("address.zig");

pub const FrameTracker  = struct {
    ppn: addr.PhysPageNum,

    const Self = @This();
    pub fn new(ppn: addr.PhysPageNum) Self {
        const bytes = ppn.get_bytes_array();
        @memset(bytes, 0);
        return Self { .ppn = ppn };
    }

    pub fn deinit(self: *const Self) void {
        
    }
};

pub fn frame_alloc() ?FrameTracker {
    return null;
}

pub fn frame_dealloc(ppn: addr.PhysPageNum) void {
    
}

