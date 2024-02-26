const std = @import("std");
const addr =  @import("address.zig");
const assert = @import("../assert.zig");
const console = @import("../console.zig");
const panic = @import("../panic.zig");
const frame_allocator = @import("frame_allocator.zig");

const ArrayList = std.ArrayList;
const FrameTracker = frame_allocator.FrameTracker;

pub const PTEFlag = enum(u8) {
    V = 1 << 0,
    R = 1 << 1,
    W = 1 << 2,
    X = 1 << 3,
    U = 1 << 4,
    G = 1 << 5,
    A = 1 << 6,
    D = 1 << 7,
};

pub const PTEFlags = struct {
    bits: u8,

    const Self = @This();
    pub fn empty() Self {
        return Self.from_bits(0);
    }

    pub fn from_bits(bits: u8) Self {
        return Self { .bits = bits };
    }

    pub fn set(self: Self, flag: PTEFlag) Self {
        return .{ .bits = self.bits | @intFromEnum(flag) };
    }

    pub fn unset(self: Self, flag: PTEFlag) Self {
        return .{ .bits =  self.bits & ~@intFromEnum(flag) };
    }

    pub fn is_set(self: *const Self, flag: PTEFlag) bool {
        return (self.bits & @intFromEnum(flag)) != 0;
    }
};

pub const PageTableEntry = extern struct {
    bits: usize,

    const Self = @This();
    pub fn new(p: addr.PhysPageNum, fgs: PTEFlags) Self {
        const flag_bits: usize = @intCast(fgs.bits);
        return Self {
            .bits = p.v << 10 | flag_bits,
        };
    }

    pub fn empty() Self {
        return Self {
            .bits = 0,
        };
    }

    pub fn ppn(self: *const Self) addr.PhysPageNum {
        const v = (self.bits >> 10 & ((@as(usize, 1) << 44) - 1));
        return addr.PhysPageNum.from(v);
    }

    pub fn flags(self: *const Self) PTEFlags {
        const flag_bits: u8 = @truncate(self.bits);
        return PTEFlags.from_bits(flag_bits);
    }

    pub fn is_valid(self: *const Self) bool {
        return self.flags().is_set(PTEFlag.V);
    }

    pub fn is_readable(self: *const Self) bool {
        return self.flags().is_set(PTEFlag.R);
    }

    pub fn is_writable(self: *const Self) bool {
        return self.flags().is_set(PTEFlag.W);
    }

    pub fn is_executable(self: *const Self) bool {
        return self.flags().is_set(PTEFlag.X);
    }
};

pub const PageTable = struct {
    root_ppn: addr.PhysPageNum,
    frames: ArrayList(FrameTracker),

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        const frame = frame_allocator.frame_alloc() orelse panic.panic("no more mem", .{});
        var frames = ArrayList(FrameTracker).init(allocator);
        frames.append(frame) catch unreachable;
        return Self {
            .root_ppn = frame.ppn,
            .frames = frames,
        };
    }

    /// Temporarily used to get arguments from user space.
    pub fn from_token(satp: usize, allocator: std.mem.Allocator) Self {
        return Self {
            .root_ppn = addr.PhysPageNum.from(satp & ((@as(usize, 1) << 44) - 1)),
            .frames = ArrayList(FrameTracker).init(allocator),
        };
    }

    fn find_pte_create(self: *Self, vpn: addr.VirtPageNum) ?*PageTableEntry {
        const idxs = vpn.indexes();
        var ppn = self.root_ppn;
        var result: ?*PageTableEntry = null;
        for (0..3) |i| {
            const pte = &ppn.get_pte_array()[idxs[i]];
            if (i == 2) {
                result = pte;
                break;
            }
            if (!pte.is_valid()) {
                const frame = frame_allocator.frame_alloc() orelse panic.panic("no more mem", .{});
                pte.* = PageTableEntry.new(frame.ppn, PTEFlags.empty().set(PTEFlag.V));
                self.frames.append(frame) catch unreachable;
            }
            ppn = pte.ppn();
        }

        return result;
    }

    fn find_pte(self: *const Self, vpn: addr.VirtPageNum) ?*const PageTableEntry {
        const idxs = vpn.indexes();
        var ppn = self.root_ppn;
        var result: ?*const PageTableEntry = null;
        for (0..3) |i| {
            const pte = &ppn.get_pte_array()[idxs[i]];
            if (i == 2) {
                result = pte;
                break;
            }
            if (!pte.is_valid()) {
                return null;
            }
            ppn = pte.ppn();
        }

        return result;
    }

    pub fn map(self: *Self, vpn: addr.VirtPageNum, ppn: addr.PhysPageNum, flags: PTEFlags) !void {
        const pte = self.find_pte_create(vpn).?;
        if (pte.is_valid()) {
            console.logger.warn("0x{x} is already mapped to 0x{x}.", .{vpn.v, pte.ppn().v});
            return error.Remapping;
        }
        pte.* = PageTableEntry.new(ppn, flags.set(PTEFlag.V));
    }

    pub fn unmap(self: *Self, vpn: addr.VirtPageNum) void {
        const pte = self.find_pte_create(vpn).?;
        assert.assert(pte.is_valid(), "vpn 0x{x} is invalid before unmapping", vpn);
        pte.* = PageTableEntry.empty();
    }

    pub fn translate(self: *const Self, vpn: addr.VirtPageNum) ?PageTableEntry {
        if (self.find_pte(vpn)) |pte| {
            return pte.*;
        } else {
            return null;
        }
    }

    pub fn token(self: *const Self) usize {
        return @as(usize, 8) << 60 | self.root_ppn.v;
    }

};

pub fn translated_byte_buffer(token: usize, ptr: *const u8, len: usize, allocator: std.mem.Allocator) !ArrayList([]u8) {
    const page_table = PageTable.from_token(token, allocator);
    var start = @intFromPtr(ptr);
    const end = start + len;
    var v = ArrayList([]u8).init(allocator);
    while (start < end) {
        const start_va = addr.VirtAddr.from(start);
        var vpn = start_va.floor();
        const ppn = page_table.translate(vpn).?.ppn();
        vpn.step();
        var end_va = addr.VirtAddr.from_vpn(vpn);
        end_va = addr.VirtAddr { .v = @min(end_va.v, addr.VirtAddr.from(end).v) };
        if (end_va.page_offset() == 0) {
            try v.append(ppn.get_bytes_array()[start_va.page_offset()..]);
        } else {
            try v.append(ppn.get_bytes_array()[start_va.page_offset()..end_va.page_offset()]);
        }
        start = end_va.v;
    }

    return v;
}

// ELF std.io.FixedBufferStream
