const std = @import("std");
const config = @import("../config.zig");
const assert = @import("../assert.zig");
const page_table = @import("page_table.zig");

const PageTableEntry = page_table.PageTableEntry;

const PA_WIDTH_SV39: usize = 56;
const VA_WIDTH_SV39: usize = 39;
const PPN_WIDTH_SV39: usize = PA_WIDTH_SV39 - config.PAGE_SIZE_BITS;
const VPN_WIDTH_SV39: usize = VA_WIDTH_SV39 - config.PAGE_SIZE_BITS;

pub const PhysAddr = struct {
    v: usize,

    const Self = @This();
    pub fn from(v: usize) Self {
        return Self { .v = v & ( (1 << PA_WIDTH_SV39) - 1 ) };
    }

    pub fn from_ppn(ppn: PhysPageNum) Self {
        return PhysAddr {
            .v = ppn.v << config.PAGE_SIZE_BITS,
        };
    }

    pub fn floor(self: *const Self) PhysPageNum { 
        return PhysPageNum{ .v = self.v / config.PAGE_SIZE };
    }

    pub fn ceil(self: *const Self) PhysPageNum  {
        return PhysPageNum{ .v =  (self.v - 1 + config.PAGE_SIZE) / config.PAGE_SIZE};
    }

    pub fn page_offset(self: *const Self) usize {
        return self.v & (config.PAGE_SIZE - 1);
    }

    pub fn aligned(self: *const Self) bool {
        return self.page_offset() == 0;
    }

    pub fn eq(lhs: Self, rhs: Self) bool {
        return lhs.v == rhs.v;
    }

    pub fn lt(lhs: Self, rhs: Self) bool {
        return lhs.v < rhs.v;
    }

    pub fn gt(lhs: Self, rhs: Self) bool {
        return lhs.v > rhs.v;
    }
};

pub const VirtAddr = struct {
    v: usize,

    const Self = @This();
    pub fn from(v: usize) Self {
        return Self { .v = v & ( (1 << VA_WIDTH_SV39) - 1 ) };
    }

    pub fn from_vpn(vpn: VirtPageNum) Self {
        return VirtAddr {
            .v = vpn.v << config.PAGE_SIZE_BITS,
        };
    }

    pub fn floor(self: *const Self) VirtPageNum { 
        return VirtPageNum{ .v = self.v / config.PAGE_SIZE };
    }

    pub fn ceil(self: *const Self) VirtPageNum  {
        return VirtPageNum{ .v =  (self.v - 1 + config.PAGE_SIZE) / config.PAGE_SIZE};
    }

    pub fn page_offset(self: *const Self) usize {
        return self.v & (config.PAGE_SIZE - 1);
    }

    pub fn aligned(self: *const Self) bool {
        return self.page_offset() == 0;
    }

    pub fn eq(lhs: Self, rhs: Self) bool {
        return lhs.v == rhs.v;
    }

    pub fn lt(lhs: Self, rhs: Self) bool {
        return lhs.v < rhs.v;
    }

    pub fn gt(lhs: Self, rhs: Self) bool {
        return lhs.v > rhs.v;
    }
};

pub const PhysPageNum = struct {
    v: usize,

    const Self = @This();
    pub fn from(v: usize) Self {
        return Self { .v = v & ( (1 << PPN_WIDTH_SV39) - 1 ) };
    }

    pub fn from_addr(pa: PhysAddr) Self {
        assert.assert_eq(pa.page_offset(), 0, @src());
        return pa.floor();
    }

    pub fn mem_area_to(self: *const Self, comptime T: type) [*]T {
        const pa = PhysAddr.from_ppn(self.*);
        return @ptrFromInt(pa.v);
    } 

    pub fn get_pte_array(self: *const Self) []PageTableEntry {
        return self.mem_area_to(PageTableEntry)[0..512];
    }

    pub fn get_bytes_array(self: *const Self) []u8 {
        return self.mem_area_to(u8)[0..4096];
    }

    pub fn get_mut(self: *const Self, comptime T: type) *T {
        return &self.mem_area_to(T)[0];
    }

    pub fn step(self: *Self) void {
        self.v += 1;
    }

    pub fn eq(lhs: Self, rhs: Self) bool {
        return lhs.v == rhs.v;
    }

    pub fn lt(lhs: Self, rhs: Self) bool {
        return lhs.v < rhs.v;
    }

    pub fn gt(lhs: Self, rhs: Self) bool {
        return lhs.v > rhs.v;
    }
};

pub const VirtPageNum = struct {
    v: usize,

    const Self = @This();
    pub fn from(v: usize) Self {
        return Self { .v = v & ( (1 << VPN_WIDTH_SV39) - 1 ) };
    }

    pub fn from_addr(va: VirtAddr) Self {
        assert.assert_eq(va.page_offset(), 0, @src());
        return va.floor();
    }

    pub fn indexes(self: *const Self) [3]usize {
        var vpn = self.v;
        var idx = [3]usize {0, 0, 0};
        var i: usize = 2;
        while (true) {
            idx[i] = vpn & 511;
            vpn >>= 9;
            if (i == 0) break;
            i -= 1;
        }

        return idx;
    }

    pub fn step(self: *Self) void {
        self.v += 1;
    }

    pub fn eq(lhs: Self, rhs: Self) bool {
        return lhs.v == rhs.v;
    }

    pub fn lt(lhs: Self, rhs: Self) bool {
        return lhs.v < rhs.v;
    }

    pub fn gt(lhs: Self, rhs: Self) bool {
        return lhs.v > rhs.v;
    }
};

pub fn SimpleRange(comptime T: type) type {
    return struct {
        l: T,
        r: T,

        const Self = @This();
        pub fn new(start: T, end: T) Self {
            assert.assert(start.v <= end.v, "VPNRange: start({d}) > end({d})", .{ start.v, end.v });
            return Self {
                .l = start,
                .r = end,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.l.v < self.r.v) {
                const n = self.l;
                self.l.step();
                return n;
            } else {
                return null;
            }
        } 
    };
}

pub const PPNRange = SimpleRange(PhysPageNum);
pub const VPNRange = SimpleRange(VirtPageNum);
