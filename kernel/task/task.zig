const std = @import("std");
const mm = @import("../mm/lib.zig");
const addr = mm.address;
const config = @import("../config.zig");
const console = @import("../console.zig");
const trap = @import("../trap/lib.zig");
const panic = @import("../panic.zig");
const pid = @import("pid.zig");

const ArrayList = std.ArrayList;
const MemSet = mm.memory_set.MemorySet;
const MapPermission = mm.memory_set.MapPermission;
const MapPermissions = mm.memory_set.MapPermissions;
const TaskContext = @import("context.zig").TaskContext;

pub const TaskStatus = enum {
    UnInit,
    Ready,
    Running,
    Zombie,
    Exited,
};

pub const TaskControlBlock = struct {
    // 为了简单起见, 这里不用引用计数了
    // 我们现在先让内存泄漏
    const Children = ArrayList(*TaskControlBlock);

    pid: pid.PidHandle,
    kernel_stack: pid.KernelStack,
    base_size: usize,
    ctx: TaskContext,
    trap_ctx_ppn: addr.PhysPageNum,
    status: TaskStatus,
    mem_set: MemSet,
    parent: ?*TaskControlBlock,
    children: Children,
    exit_code: i32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn is_zombie(self: *const Self) bool {
        return self.status == .Zombie;
    }

    pub fn get_trap_ctx(self: *const Self) *trap.TrapContext {
        return self.trap_ctx_ppn.get_mut(trap.TrapContext);
    }

    pub fn get_user_token(self: *const Self) usize {
        return self.mem_set.token();
    }

    pub fn getpid(self: *const Self) usize {
        return self.pid.v;
    }

    pub fn new(allocator: std.mem.Allocator, elf_data: []u8) !Self {
        const elf_mem_info = try MemSet.from_elf(allocator, elf_data);
        const mem_set = elf_mem_info.mem_set;
        const trap_ctx_ppn = mem_set
            .translate(addr.VirtPageNum.from_addr(addr.VirtAddr.from(config.TRAP_CONTEXT)))
            .?
            .ppn();
        // alloc a pid and a kernel stack in kernel space
        const pid_hd = pid.pid_alloc();
        const kernel_stack = pid.KernelStack.init(pid_hd);
        const kernel_stack_top = kernel_stack.get_info().top;
        // push a task context which goes to trap_return to the top of kernel stack
        const task_control_block = Self {
            .pid = pid_hd,
            .kernel_stack = kernel_stack,
            .base_size = elf_mem_info.user_stack_top,
            .ctx = TaskContext.goto_trap_return(kernel_stack_top),
            .trap_ctx_ppn = trap_ctx_ppn,
            .status = TaskStatus.Ready,
            .mem_set = mem_set,
            .parent = null,
            .children = Children.init(allocator),
            .exit_code = 0,
            .allocator = allocator,
        };

        // prepare TrapContext in user space
        const trap_ctx = task_control_block.get_trap_ctx();
        trap_ctx.* = trap.TrapContext.app_init_context(
            elf_mem_info.entry_point,
            elf_mem_info.user_stack_top,
            mm.memory_set.kernel_space_token(),
            kernel_stack_top,
            @intFromPtr(&trap.trap_handler),
        );

        return task_control_block;
    }

    pub fn exec(self: *Self, elf_data: []u8) !void {
        const elf_mem_info = try MemSet.from_elf(self.allocator, elf_data);
        const mem_set = elf_mem_info.mem_set;
        const trap_ctx_ppn = mem_set
            .translate(addr.VirtPageNum.from_addr(addr.VirtAddr.from(config.TRAP_CONTEXT)))
            .?
            .ppn();
        // substitute memory_set
        self.mem_set = mem_set;
        // update trap_ctx ppn
        self.trap_ctx_ppn = trap_ctx_ppn;
        // initialize trap_ctx
        const trap_ctx = self.get_trap_ctx();
        trap_ctx.* = trap.TrapContext.app_init_context(
            elf_mem_info.entry_point,
            elf_mem_info.user_stack_top,
            mm.memory_set.kernel_space_token(),
            self.kernel_stack.get_info().top,
            @intFromPtr(&trap.trap_handler),
        );
    }

    pub fn fork(self: *TaskControlBlock) !*TaskControlBlock {
        const mem_set = try MemSet.from_existed_user(&self.mem_set, self.allocator);
        // TODO: 将这个抽象一下
        const trap_ctx_ppn = mem_set
            .translate(addr.VirtPageNum.from_addr(addr.VirtAddr.from(config.TRAP_CONTEXT)))
            .?
            .ppn();
        // alloc a pid and a kernel stack in kernel space
        const pid_hd = pid.pid_alloc();
        const kernel_stack = pid.KernelStack.init(pid_hd);
        const kernel_stack_top = kernel_stack.get_info().top;
        // push a task context which goes to trap_return to the top of kernel stack
        const task_control_block = try self.allocator.create(Self);
        task_control_block.* = Self {
            .pid = pid_hd,
            .kernel_stack = kernel_stack,
            .base_size = self.base_size,
            .ctx = TaskContext.goto_trap_return(kernel_stack_top),
            .trap_ctx_ppn = trap_ctx_ppn,
            .status = TaskStatus.Ready,
            .mem_set = mem_set,
            .parent = self,
            .children = Children.init(self.allocator),
            .exit_code = 0,
            .allocator = self.allocator,
        };
        // add child
        try self.children.append(task_control_block);
        task_control_block.get_trap_ctx().kernel_sp = kernel_stack_top;
        return task_control_block;
    }
};

