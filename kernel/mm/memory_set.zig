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
var KERNEL_SPACE: MemorySet = undefined;

pub fn init_kernel_space(allocator: std.mem.Allocator) void {
    KERNEL_SPACE = MemorySet.new_kernel(allocator);
    KERNEL_SPACE.activate();
}

pub fn kernel_space_insert_framed_area(start_va: addr.VirtAddr, end_va: addr.VirtAddr, permissions: MapPermissions) !void {
    KERNEL_SPACE_LOCK.acquire();
    defer KERNEL_SPACE_LOCK.release();
    try KERNEL_SPACE.insert_framed_area(start_va, end_va, permissions);
}

pub fn kernel_space_remove_area_with_start_vpn(start_vpn: addr.VirtPageNum) void {
    KERNEL_SPACE_LOCK.acquire();
    defer KERNEL_SPACE_LOCK.release();
    KERNEL_SPACE.remove_area_with_start_vpn(start_vpn);
}

pub fn kernel_space_token() usize {
    return KERNEL_SPACE.token();
}

// TDOD: manage memeory: init and deinit pair
// we let it leak now

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
    W = 1 << 2,
    X = 1 << 3,
    U = 1 << 4,
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

    pub fn set(self: Self, flag: MapPermission) Self {
        return .{ .bits = self.bits | @intFromEnum(flag) };
    }

    pub fn unset(self: Self, flag: MapPermission) Self {
        return .{ .bits = self.bits & ~@intFromEnum(flag) };
    }
};

pub const MapType = enum {
    Identical,
    Framed,
};

pub const MapArea = struct {
    const MemMap: type = BTreeMap(addr.VirtPageNum, FrameTracker);

    vpn_range: addr.VPNRange,
    data_frames: MemMap,
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
            .vpn_range = addr.VPNRange.new(start_va.floor(), end_va.ceil()),
            .data_frames = MemMap.init(allocator),
            .map_type = map_type,
            .map_perm = map_perm,
        };
    }

    pub fn deinit(self: *Self) !void {
        var iter = try self.data_frames.iteratorInit();
        while (try iter.next()) |kv_pair| {
            kv_pair.value.deinit();
        }
        try self.data_frames.deinit();
    }

    pub fn from_another(another: *const MapArea, allocator: std.mem.Allocator) Self {
        return Self {
            .vpn_range = another.vpn_range,
            .data_frames = MemMap.init(allocator),
            .map_type = another.map_type,
            .map_perm = another.map_perm,
        };
    }

    pub fn contains(self: *Self, va: addr.VirtAddr) bool {
        return self.vpn_range.contains(va.floor());
    }

    pub fn map_one(self: *Self, page_table: *PageTable, vpn: addr.VirtPageNum) !void {
        var ppn: addr.PhysPageNum = undefined;
        switch (self.map_type) {
            .Identical => {
                ppn = addr.PhysPageNum { .v = vpn.v };
                const pte_flags = PTEFlags.from_bits(self.map_perm.bits);
                try page_table.map(vpn, ppn, pte_flags);
            },
            .Framed => {
                const frame = frame_allocator.frame_alloc() orelse panic.panic("no more mem", .{});
                ppn = frame.ppn;
                errdefer {
                    frame.deinit();
                    _ = self.data_frames.fetchRemove(vpn) catch {};
                }
                _ = try self.data_frames.fetchPut(vpn, frame);
                const pte_flags = PTEFlags.from_bits(self.map_perm.bits);
                try page_table.map(vpn, ppn, pte_flags);
            },
        }
    }

    pub fn unmap_one(self: *Self, page_table: *PageTable, vpn: addr.VirtPageNum) void {
        switch (self.map_type) {
            .Framed => {
                const kv_pair = self.data_frames.fetchRemove(vpn)
                    catch |e| panic.panic("Failed to unmap 0x{x}: {}", .{vpn.v, e})
                    orelse return;
                kv_pair.value.deinit();
            },
            else => {}
        }
        page_table.unmap(vpn);
    }

    pub fn map(self: *Self, page_table: *PageTable) !void {
        var vpn_range = self.vpn_range;
        while (vpn_range.next()) |vpn| {
            try self.map_one(page_table, vpn);
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
        var current_vpn = self.vpn_range.l;
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
    allocator: std.mem.Allocator,

    const Self = @This();
    pub fn new_bare(allocator: std.mem.Allocator) Self {
        return Self {
            .page_table = PageTable.init(allocator),
            .areas = ArrayList(MapArea).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.areas.items) |*item| {
            item.deinit() catch |e| {
                panic.panic("Failed to release mem area: {}", .{e});
            };
        }
        self.areas.deinit();
        self.page_table.deinit();
    }

    pub fn token(self: *const Self) usize {
        return self.page_table.token();
    }

    pub fn insert_framed_area(self: *Self, start_va: addr.VirtAddr, end_va: addr.VirtAddr, permissions: MapPermissions) !void {
        try self.push(MapArea.new(
            start_va,
            end_va,
            MapType.Framed,
            permissions,
            self.allocator,
        ), null);
    }

    fn push(self: *Self, map_area: MapArea, data: ?[]u8) !void {
        var mut_map_area = map_area;
        try mut_map_area.map(&self.page_table);
        if (data) |d| {
            mut_map_area.copy_data(&self.page_table, d);
        }
        self.areas.append(mut_map_area) catch unreachable;
    }

    pub fn remove(self: *Self, start_va: addr.VirtAddr, end_va: addr.VirtAddr) !void {
        const end_vpn = end_va.ceil();
        const len = self.areas.items.len;
        for (0..len) |i| {
            if (self.areas.items[i].contains(start_va)) {
                const area = &self.areas.items[i];
                var unmap_area: MapArea = undefined;
                if (end_vpn.v == area.vpn_range.r.v) {
                    unmap_area = self.areas.orderedRemove(i);
                } else if (end_vpn.v > area.vpn_range.r.v) {
                    return error.InvalidMemArea;
                } else {
                    unmap_area = area.*;
                    unmap_area.vpn_range.r = end_vpn;
                    area.vpn_range.l = end_vpn;
                }
                unmap_area.unmap(&self.page_table);
                return;
            }
        }
        return error.MemAreaNotFound;
    }

    pub fn remove_area_with_start_vpn(self: *Self, start_vpn: addr.VirtPageNum) void {
        const len = self.areas.items.len;
        for (0..len) |i| {
            if (self.areas.items[i].vpn_range.l.v == start_vpn.v) {
                var unmap_area: MapArea = self.areas.orderedRemove(i);
                unmap_area.unmap(&self.page_table);
                return;
            }
        }
    }

    fn map_trampoline(self: *Self) void {
        self.page_table.map(
            addr.VirtPageNum.from_addr(addr.VirtAddr.from(config.TRAMPOLINE)), 
            addr.PhysPageNum.from_addr(addr.PhysAddr.from(@intFromPtr(&strampoline))),
            PTEFlags.empty().set(PTEFlag.R).set(PTEFlag.X)
        ) catch panic.panic("Faield to map trampoline", .{});
    }

    pub fn activate(self: *Self) void {
        const satp = self.page_table.token();
        riscv.regs.satp.write(satp);
        asm volatile ("sfence.vma" ::: "memory");
    }

    pub fn translate(self: *const Self, vpn: addr.VirtPageNum) ?PageTableEntry {
        return self.page_table.translate(vpn);
    }

    pub fn recycle_data_pages(self: *Self) void {
        for (0..self.areas.items.len) |i| {
            self.areas.items[i].deinit() catch |e| {
                console.logger.warn("Failed to free mapArea: {}", .{e});
                return;
            };
        }
        self.areas.items.len = 0;
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
            addr.VirtAddr.from(@intFromPtr(&stext)),
            addr.VirtAddr.from(@intFromPtr(&etext)),
            MapType.Identical,
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.X),
            allocator,
        ), null) catch {};
        
        console.logger.info("mapping .rodata section", .{});
        memory_set.push(MapArea.new(
            addr.VirtAddr.from(@intFromPtr(&srodata)),
            addr.VirtAddr.from(@intFromPtr(&erodata)),
            MapType.Identical,
            MapPermissions.empty().set(MapPermission.R),
            allocator,
        ), null) catch {};

        console.logger.info("mapping .data section", .{});
        memory_set.push(MapArea.new(
            addr.VirtAddr.from(@intFromPtr(&sdata)),
            addr.VirtAddr.from(@intFromPtr(&edata)),
            MapType.Identical,
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.W),
            allocator,
        ), null) catch {};

        console.logger.info("mapping .bss section", .{});
        memory_set.push(MapArea.new(
            addr.VirtAddr.from(@intFromPtr(&sbss_with_stack)),
            addr.VirtAddr.from(@intFromPtr(&ebss)),
            MapType.Identical,
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.W),
            allocator,
        ), null) catch {};

        console.logger.info("mapping physical memory", .{});
        memory_set.push(MapArea.new(
            addr.VirtAddr.from(@intFromPtr(&ekernel)),
            addr.VirtAddr.from(config.MEMORY_END),
            MapType.Identical,
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.W),
            allocator,
        ), null) catch {};

        return memory_set;
    }

    pub fn from_elf(allocator: std.mem.Allocator, elf_data: []u8) !ELFMemInfo {
        var mem_set = Self.new_bare(allocator);
        mem_set.map_trampoline();

        var elf_buf = std.io.fixedBufferStream(elf_data);
        const header = std.elf.Header.read(&elf_buf) catch |e| panic.panic("Faield to parse elf: {}", .{e});
        var prog_header_iter = header.program_header_iterator(elf_buf);

        const PROG_TYPE_LOAD: u32 = 1;
        const FLAG_X: u32 = 0x1;
        const FLAG_W: u32 = 0x2;
        const FLAG_R: u32 = 0x4;

        var max_end_vpn = addr.VirtPageNum { .v = 0 };
        while (try prog_header_iter.next()) |prog_hd| {
            if (prog_hd.p_type == PROG_TYPE_LOAD) {
                const va: usize = @intCast(prog_hd.p_vaddr);
                const start_va = addr.VirtAddr.from(va);
                const end_va = addr.VirtAddr.from(va + @as(usize, @intCast(prog_hd.p_memsz)));
                var map_perm = MapPermissions.empty().set(MapPermission.U);
                const ph_flags = prog_hd.p_flags;
                if (ph_flags & FLAG_R == FLAG_R) {
                    map_perm = map_perm.set(MapPermission.R);
                }
                if (ph_flags & FLAG_W == FLAG_W) {
                    map_perm = map_perm.set(MapPermission.W);
                }
                if (ph_flags & FLAG_X == FLAG_X) {
                    map_perm = map_perm.set(MapPermission.X);
                }
                const map_area = MapArea.new(
                    start_va,
                    end_va,
                    MapType.Framed,
                    map_perm,
                    allocator,
                );

                const offset: usize = @intCast(prog_hd.p_offset);
                const filesz: usize = @intCast(prog_hd.p_filesz);
                mem_set.push(
                    map_area,
                    elf_data[offset..(offset + filesz)]
                ) catch {};
                max_end_vpn = map_area.vpn_range.r;
            }
        }
        // map user stack
        const max_end_va = addr.VirtAddr.from_vpn(max_end_vpn);
        var user_stack_bottom = max_end_va.v;
        // guard page
        user_stack_bottom += config.PAGE_SIZE;
        const user_stack_top = user_stack_bottom + config.USER_STACK_SIZE;
        mem_set.push(MapArea.new(
            addr.VirtAddr.from(user_stack_bottom),
            addr.VirtAddr.from(user_stack_top),
            MapType.Framed,
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.W).set(MapPermission.U),
            allocator,
        ), null) catch |e| panic.panic("Failed to map user stack: {}", .{e});
        // map TrapContext
        mem_set.push(MapArea.new(
            addr.VirtAddr.from(config.TRAP_CONTEXT),
            addr.VirtAddr.from(config.TRAMPOLINE),
            MapType.Framed,
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.W),
            allocator,
        ), null) catch |e| panic.panic("Failed to map trap context: {}", .{e});
        return ELFMemInfo {
            .mem_set = mem_set,
            .user_stack_top = user_stack_top,
            .entry_point = @intCast(header.entry),
        };
    }

    pub fn from_existed_user(user_space: *const MemorySet, allocator: std.mem.Allocator) !MemorySet {
        var mem_set = Self.new_bare(allocator);
        mem_set.map_trampoline();
        // copy data sections/trap_context/user_stack
        for (user_space.areas.items) |*area| {
            const new_area = MapArea.from_another(area, allocator);
            try mem_set.push(new_area, null);
            // copy data from another space
            var vpn_range = area.vpn_range;
            while (vpn_range.next()) |vpn| {
                const src_ppn = user_space.translate(vpn).?.ppn();
                const dst_ppn = mem_set.translate(vpn).?.ppn();
                @memcpy(dst_ppn.get_bytes_array(), src_ppn.get_bytes_array());
            }
        }
        return mem_set;
    }
};

pub fn remap_test() void {
    const mid_text = addr.VirtAddr.from((@intFromPtr(&stext) + @intFromPtr(&etext)) / 2);
    const mid_rodata = addr.VirtAddr.from((@intFromPtr(&srodata) + @intFromPtr(&erodata)) / 2);
    const mid_data = addr.VirtAddr.from((@intFromPtr(&sdata) + @intFromPtr(&edata)) / 2);
    assert.assert(
        !KERNEL_SPACE.page_table
            .translate(mid_text.floor())
            .?
            .is_writable(), 
        "mid_text should not be writable", 
        .{}
    );
    assert.assert(
        !KERNEL_SPACE.page_table
            .translate(mid_rodata.floor())
            .?
            .is_writable(), 
        "mid_rodata should not be writable", 
        .{}
    );
    assert.assert(
        !KERNEL_SPACE.page_table
            .translate(mid_data.floor())
            .?
            .is_executable(),
        "mid_data should not be executable", 
        .{}
    );
}