const console = @import("console.zig");

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const math = std.math;
const mem = std.mem;
const isPowerOfTwo = math.isPowerOfTwo;
const Allocator = mem.Allocator;

pub const Log2Size = math.Log2Int(usize);

pub const Check = std.heap.Check;

// Thread-safety

pub const Buddy2Allocator = struct {
    const Self = @This();

    manager: *Buddy2,
    bytes: []u8,

    pub fn init(bytes: []u8) Self {
        var ctx_len = bytes.len / 3 * 2;
        if (!isPowerOfTwo(ctx_len)) {
            ctx_len = fixLen(ctx_len) >> 1;
        }
        return Self{
            .manager = Buddy2.init(bytes[0..ctx_len]),
            .bytes = bytes[ctx_len..],
        };
    }

    pub fn detectLeaks(self: *const Self) bool {
        const slice: []u8 = @as([*]u8, @ptrCast(&self.manager._longest))[0 .. self.manager.getLen() * 2 - 1];
        var leaks = false;
        for (slice) |longest| {
            if (longest == 0) {
                leaks = true;
            }
        }
        return leaks;
    }

    pub fn deinit(self: *Self) Check {
        const leaks = self.detectLeaks();
        self.* = undefined;
        return @as(Check, @enumFromInt(@intFromBool(leaks)));
    }

    pub fn allocator(self: *Self) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        const ptr = self.alignedAlloc(len, log2_ptr_align);
        return ptr;
    }

    fn alignedAlloc(self: *Self, len: usize, log2_ptr_align: u8) ?[*]u8 {
        const alignment = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_ptr_align));

        var unaligned_ptr = @as([*]u8, @ptrCast(self.unalignedAlloc(len + alignment - 1) orelse return null));
        const unaligned_addr = @intFromPtr(unaligned_ptr);
        const aligned_addr = mem.alignForward(usize, unaligned_addr, alignment);

        return unaligned_ptr + (aligned_addr - unaligned_addr);
    }

    fn unalignedAlloc(self: *Self, len: usize) ?[*]u8 {
        const offset = self.manager.alloc(len) orelse return null;
        return @ptrFromInt(@intFromPtr(self.bytes.ptr) + offset);
    }

    fn resize(ctx: *anyopaque, buf: []u8, log2_old_align: u8, new_len: usize, ret_addr: usize) bool {
        _ = log2_old_align;
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        const ok = new_len <= self.alignedAllocSize(buf.ptr);
        return ok;
    }

    fn alignedAllocSize(self: *Self, ptr: [*]u8) usize {
        const aligned_offset = @intFromPtr(ptr) - @intFromPtr(self.bytes.ptr);
        const index = self.manager.backward(aligned_offset);

        const unaligned_offset = self.manager.indexToOffset(index);
        const unaligned_size = self.manager.indexToSize(index);

        return unaligned_size - (aligned_offset - unaligned_offset);
    }

    fn free(ctx: *anyopaque, buf: []u8, log2_old_align: u8, ret_addr: usize) void {
        _ = log2_old_align;
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.alignedFree(buf.ptr);
    }

    fn alignedFree(self: *Self, ptr: [*]u8) void {
        self.manager.free(@intFromPtr(ptr) - @intFromPtr(self.bytes.ptr));
    }
};

pub const Buddy2 = struct {
    const Self = @This();

    _len: u8,
    _longest: [1]u8,

    pub fn init(ctx: []u8) *Self {
        const len = ctx.len / 2;
        assert(isPowerOfTwo(len));

        const self: *Self = @ptrCast(@alignCast(ctx));
        self.setLen(len);
        var node_size = len * 2;

        for (0..2 * len - 1) |i| {
            if (isPowerOfTwo(i + 1)) {
                node_size /= 2;
            }
            self.setLongest(i, node_size);
        }
        return self;
    }

    pub fn alloc(self: *Self, len: usize) ?usize {
        const new_len = fixLen(len);
        var index: usize = 0;

        if (self.getLongest(index) < new_len) {
            return null;
        }

        var node_size = self.getLen();
        while (node_size != new_len) : (node_size /= 2) {
            const left_longest = self.getLongest(left(index));
            const right_longest = self.getLongest(right(index));
            if (left_longest >= new_len and (right_longest < new_len or right_longest >= left_longest)) {
                index = left(index);
            } else {
                index = right(index);
            }
        }

        self.setLongest(index, 0);
        // const offset = self.indexToOffset(index);
        const offset = (index + 1) * node_size - self.getLen();

        while (index != 0) {
            index = parent(index);
            self.setLongest(index, @max(self.getLongest(left(index)), self.getLongest(right(index))));
        }

        return offset;
    }

    pub fn free(self: *Self, offset: usize) void {
        console.logger.info("in Free 1", .{});
        assert(offset >= 0 and offset < self.getLen());
        console.logger.info("in Free 2", .{});

        var node_size: usize = 1;
        var index = offset + self.getLen() - 1;

        while (self.getLongest(index) != 0) : (index = parent(index)) {
            node_size *= 2;
            if (index == 0) {
                return;
            }
        }
        self.setLongest(index, node_size);

        while (index != 0) {
            console.logger.info("in Free 3", .{});
            index = parent(index);
            node_size *= 2;

            const left_longest = self.getLongest(left(index));
            const right_longest = self.getLongest(right(index));

            if (left_longest + right_longest == node_size) {
                self.setLongest(index, node_size);
            } else {
                self.setLongest(index, @max(left_longest, right_longest));
            }
        }

        console.logger.info("Free Done", .{});
    }

    pub fn size(self: *const Self, offset: usize) usize {
        return self.indexToSize(self.backward(offset));
    }

    fn backward(self: *const Self, offset: usize) usize {
        assert(offset >= 0 and offset < self.getLen());

        var index = offset + self.getLen() - 1;
        while (self.getLongest(index) != 0) {
            index = parent(index);
        }

        return index;
    }

    inline fn getLen(self: *const Self) usize {
        return @as(usize, 1) << @as(Log2Size, @intCast(self._len));
    }

    inline fn setLen(self: *Self, len: usize) void {
        self._len = math.log2_int(usize, len);
    }

    inline fn indexToSize(self: *const Self, index: usize) usize {
        return self.getLen() >> math.log2_int(usize, index + 1);
    }

    inline fn indexToOffset(self: *const Self, index: usize) usize {
        // return (index + 1) * node_size - self.len;
        return (index + 1) * self.indexToSize(index) - self.getLen();
    }

    inline fn getLongest(self: *const Self, index: usize) usize {
        const ptr: [*]const u8 = @ptrCast(&self._longest);
        const node_size = ptr[index];
        // if (node_size == 0) {
        //     return 0;
        // }
        // return @as(usize, 1) << @truncate(node_size - 1);
        return (@as(usize, 1) << @as(Log2Size, @intCast(node_size))) >> 1;
    }

    inline fn setLongest(self: *Self, index: usize, node_size: usize) void {
        const ptr: [*]u8 = @ptrCast(&self._longest);
        // if (node_size == 0) {
        //     ptr[index] = 0;
        //     return;
        // }
        // ptr[index] = math.log2_int(usize, node_size) + 1;
        ptr[index] = math.log2_int(usize, (node_size << 1) | 1);
    }

    inline fn left(index: usize) usize {
        return index * 2 + 1;
    }

    inline fn right(index: usize) usize {
        return index * 2 + 2;
    }

    inline fn parent(index: usize) usize {
        return (index + 1) / 2 - 1;
    }
};

const fixLen = switch (@sizeOf(usize)) {
    4 => fixLen32,
    8 => fixLen64,
    else => @panic("unsupported arch"),
};

fn fixLen32(len: usize) usize {
    var n = len - 1;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
    if (n < 0) {
        return 1;
    }
    return n + 1;
}

fn fixLen64(len: usize) usize {
    var n = len - 1;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
    n |= n >> 32;
    if (n < 0) {
        return 1;
    }
    return n + 1;
}
