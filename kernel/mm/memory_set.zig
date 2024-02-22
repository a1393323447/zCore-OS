const std = @import("std");
const shared = @import("shared");
const assert = @import("../assert.zig");
const addr = @import("address.zig");
const btreemap = @import("shared").btreemap;
const config = @import("../config.zig");
const console = @import("../console.zig");
const panic = @import("../panic.zig");
const ptable = @import("page_table.zig");
const riscv = @import("../riscv/lib.zig");
const frame_allocator = @import("frame_allocator.zig");

const ArrayList = std.ArrayList;
const BTreeMap = btreemap.BTreeMap;
const PTEFlag = ptable.PTEFlag;
const PTEFlags = ptable.PTEFlags;
const PageTable = ptable.PageTable;
const PageTableEntry = ptable.PageTableEntry;
const FrameTracker = frame_allocator.FrameTracker;

var KERNEL_SPACE_LOCK = shared.lock.SpinLock.init();
pub var KERNEL_SPACE: MemorySet = undefined;

// TODO: This function should be called somewhere
pub fn init_kernel_space(allocator: std.mem.Allocator) void {
    KERNEL_SPACE = MemorySet.new_kernel(allocator);
}

pub fn kernel_space_insert_framed_area(start_va: addr.VirtAddr, end_va: addr.VirtAddr, permissions: MapPermissions) void {
    KERNEL_SPACE_LOCK.acquire();
    defer KERNEL_SPACE_LOCK.release();
    KERNEL_SPACE.insert_framed_area(start_va, end_va, permissions);
}

pub fn kernel_space_token() usize {
    return KERNEL_SPACE.token();
}

// TDOD: manage memeory: init and deinit pair

extern fn stext() noreturn;
extern fn etext() noreturn;
extern fn srodata() noreturn;
extern fn erodata() noreturn;
extern fn sdata() noreturn;
extern fn edata() noreturn;
extern fn sbss_with_stack() noreturn;
extern fn ebss() noreturn;
extern fn ekernel() noreturn;
extern fn strampoline() noreturn;

pub const MapPermission = enum(u8) {
    R = 1 << 1,
    W = 1 << 1,
    X = 1 << 1,
    U = 1 << 1,
};

pub const MapPermissions = struct {
    bits: u8,

    const Self = @This();
    pub fn empty() Self {
        return Self.from_bits(0);
    }

    pub fn from_bits(bits: u8) Self {
        return Self { .bits = bits };
    }

    pub fn set(self: *Self, flag: MapPermission) Self {
        self.* = self.* | @intFromEnum(flag);
        return self.*;
    }

    pub fn unset(self: *Self, flag: MapPermission) Self {
        self.* = self.* & ~@intFromEnum(flag);
        return self.*;
    }
};

pub const MapType = enum {
    Identical,
    Framed,
};

pub const MapArea = struct {
    const MemMap: type = BTreeMap(addr.VirtAddr, FrameTracker);

    vpn_range: addr.VPNRange,
    data_frames: BTreeMap(addr.VirtAddr, FrameTracker),
    map_type: MapType,
    map_perm: MapPermissions,

    const Self = @This();
    pub fn new(
        start_va: addr.VirtAddr, 
        end_va: addr.VirtAddr, 
        map_type: MapType, 
        map_perm: MapPermissions,
        allocator: std.mem.Allocator,
    ) Self {
        return Self {
            .vpn_range = addr.VPNRange.new(start_va, end_va),
            .data_frams = BTreeMap(addr.VirtAddr, FrameTracker).init(allocator),
            .map_type = map_type,
            .map_perm = map_perm,
        };
    }

    pub fn map_one(self: *Self, page_table: *PageTable, vpn: addr.VirtPageNum) void {
        var ppn: addr.PhysPageNum = undefined;
        switch (self.map_type) {
            .Identical => {
                ppn = addr.PhysPageNum { .v = vpn.v };
            },
            .Framed => {
                const frame = frame_allocator.frame_alloc().?;
                ppn = frame.ppn;
                self.data_frames.fetchPut(vpn, frame) catch unreachable;
            },
        }
        const pte_flags = PTEFlags.from_bits(self.map_perm.bits);
        page_table.map(vpn, ppn, pte_flags);
    }

    pub fn unmap_one(self: *Self, page_table: *PageTable, vpn: addr.VirtPageNum) void {
        switch (self.map_type) {
            .Framed => {
                const kv_pair = self.data_frames.fetchRemove(vpn) catch |e| panic.panic("Failed to remove frame due to {}", .{e});
                kv_pair.?.value.deinit();
            },
            else => {}
        }
        page_table.unmap(vpn);
    }

    pub fn map(self: *Self, page_table: *PageTable) void {
        var vpn_range = self.vpn_range;
        while (vpn_range.next()) |vpn| {
            self.map_one(page_table, vpn);
        }
    }

    pub fn unmap(self: *Self, page_table: *PageTable) void {
        var vpn_range = self.vpn_range;
        while (vpn_range.next()) |vpn| {
            self.unmap_one(page_table, vpn);
        }
    }

    pub fn copy_data(self: *Self, page_table: *PageTable, data: []u8) void {
        assert.assert_eq(self.map_type, MapType.Framed, @src());
        var start: usize = 0;
        var current_vpn = self.vpn_range.get_start();
        const len = data.len;
        while (true) {
            const src = data[start..@min(len, start + config.PAGE_SIZE)];
            const dst = page_table
                .translate(current_vpn)
                .?
                .ppn()
                .get_bytes_array()[0..src.len];
            @memcpy(dst, src);
            start += config.PAGE_SIZE;
            if (start >= len) {
                break;
            }
            current_vpn.step();
        }
    }
};

pub const ELFMemInfo = struct {
    mem_set: MemorySet,
    user_stack_top: usize,
    entry_point: usize,
};

pub const MemorySet = struct {
    page_table: PageTable,
    areas: ArrayList(MapArea),

    const Self = @This();
    pub fn new_bare(allocator: std.mem.Allocator) Self {
        return Self {
            .page_table = PageTable.init(allocator),
            .areas = ArrayList(MapArea).init(allocator),
        };
    }

    pub fn token(self: *const Self) usize {
        return self.page_table.token();
    }

    pub fn insert_framed_area(self: *Self, start_va: addr.VirtAddr, end_va: addr.VirtAddr, permissions: MapPermissions) void {
        self.push(MapArea.new(
            start_va,
            end_va, 
            MapType.Framed,
            permissions
        ), null);
    }

    fn push(self: *Self, map_area: MapArea, data: ?[]u8) void {
        map_area.map(&self.page_table);
        if (data) |d| {
            map_area.copy_data(&self.page_table, d);
        }
        self.areas.append(map_area);
    }

    fn map_trampoline(self: *Self) void {
        self.page_table.map(
            addr.VirtPageNum.from_addr(addr.VirtAddr.from(config.TRAMPOLINE)), 
            addr.PhysPageNum.from_addr(addr.PhysAddr.from(@intFromPtr(&strampoline))),
            PTEFlags.empty().set(PTEFlag.R).set(PTEFlag.X)
        );
    }

    pub fn activate(self: *Self) void {
        const satp = self.page_table.token();
        riscv.regs.satp.write(satp);
        asm volatile ("sfence.vma" ::: "memory");
    }

    pub fn translate(self: *const Self, vpn: addr.VirtPageNum) ?PageTableEntry {
        return self.page_table.translate(vpn);
    }

    pub fn new_kernel(allocator: std.mem.Allocator) Self {
        var memory_set = Self.new_bare(allocator);
        memory_set.map_trampoline();
        // map kernel sections
        console.logger.info(".text [{x}, {x}]", .{@intFromPtr(&stext), @intFromPtr(&etext)});
        console.logger.info(".rodata [{x}, {x}]", .{@intFromPtr(&srodata), @intFromPtr(&erodata)});
        console.logger.info(".data [{x}, {x}]", .{@intFromPtr(&sdata), @intFromPtr(&edata)});
        console.logger.info(".bss [{x}, {x}]", .{@intFromPtr(&sbss_with_stack), @intFromPtr(&ebss)});

        console.logger.info("mapping .text section", .{});
        memory_set.push(MapArea.new(
            @intFromPtr(&stext),
            @intFromPtr(&etext),
            MapType.Identical,
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.W),
        ), null);
        
        console.logger.info("mapping .rodata section", .{});
        memory_set.push(MapArea.new(
            @intFromPtr(&srodata),
            @intFromPtr(&erodata),
            MapType.Identical,
            MapPermissions.empty().set(MapPermission.R),
        ), null);

        console.logger.info("mapping .data section", .{});
        memory_set.push(MapArea.new(
            @intFromPtr(&sdata),
            @intFromPtr(&edata),
            MapType.Identical,
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.W),
        ), null);

        console.logger.info("mapping .bss section", .{});
        memory_set.push(MapArea.new(
            @intFromPtr(&sbss_with_stack),
            @intFromPtr(&ebss),
            MapType.Identical,
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.W),
        ), null);

        console.logger.info("mapping physical memory", .{});
        memory_set.push(MapArea.new(
            @intFromPtr(&ekernel),
            addr.VirtAddr.from(config.MEMORY_END),
            MapType.Identical,
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.W),
        ), null);

        return memory_set;
    }

    pub fn from_elf(elf_data: []u8) ELFMemInfo {

    }

};

// btreemap: https://github.com/pmkap/zig-btreemap/blob/main/src/btreemap.zig
