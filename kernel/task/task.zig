const std = @import("std");
const mm = @import("../mm/lib.zig");
const addr = mm.address;
const config = @import("../config.zig");
const console = @import("../console.zig");
const trap = @import("../trap/lib.zig");
const panic = @import("../panic.zig");

const MemSet = mm.memory_set.MemorySet;
const MapPermission = mm.memory_set.MapPermission;
const MapPermissions = mm.memory_set.MapPermissions;
const TaskContext = @import("context.zig").TaskContext;

pub const TaskStatus = enum {
    UnInit,
    Ready,
    Running,
    Exited,
};

pub const TaskControlBlock = struct {
    status: TaskStatus,
    ctx: TaskContext,
    mem_set: MemSet,
    trap_ctx_ppn: addr.PhysPageNum,
    base_size: usize,

    const Self = @This();

    pub fn get_trap_ctx(self: *const Self) *trap.TrapContext {
        return self.trap_ctx_ppn.get_mut(trap.TrapContext);
    }

    pub fn get_user_token(self: *const Self) usize {
        return self.mem_set.token();
    }

    pub fn new(allocator: std.mem.Allocator, elf_data: []u8, app_id: usize) !Self {
        const elf_mem_info = try MemSet.from_elf(allocator, elf_data);
        const mem_set = elf_mem_info.mem_set;
        const trap_ctx_ppn = mem_set
            .translate(addr.VirtPageNum.from_addr(addr.VirtAddr.from(config.TRAP_CONTEXT)))
            .?
            .ppn();
        const task_status = TaskStatus.Ready;
        const kernel_stack_info = config.kernel_stack_position(app_id);
        mm.memory_set.kernel_space_insert_framed_area(
            addr.VirtAddr.from(kernel_stack_info.bottom),
            addr.VirtAddr.from(kernel_stack_info.top),
            MapPermissions.empty().set(MapPermission.R).set(MapPermission.W),
        ) catch panic.panic("Failed to map kernel stack", .{});

        const task_control_block = Self {
            .status = task_status,
            .ctx = TaskContext.goto_trap_return(kernel_stack_info.top),
            .mem_set = mem_set,
            .trap_ctx_ppn = trap_ctx_ppn,
            .base_size = elf_mem_info.user_stack_top,
        };

        // prepare TrapContext in user space
        const trap_ctx = task_control_block.get_trap_ctx();
        trap_ctx.* = trap.TrapContext.app_init_context(
            elf_mem_info.entry_point,
            elf_mem_info.user_stack_top,
            mm.memory_set.kernel_space_token(),
            kernel_stack_info.top,
            @intFromPtr(&trap.trap_handler),
        );

        console.logger.debug("entry 0x{x}", .{elf_mem_info.entry_point});

        return task_control_block;
    }
};

