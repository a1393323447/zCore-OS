const std = @import("std");
const mm = @import("../mm/lib.zig");
const addr = mm.address;
const assert = @import("../assert.zig");
const config = @import("../config.zig");
const console = @import("../console.zig");
const trap = @import("../trap/lib.zig");
const timer = @import("../timer.zig");
const panic = @import("../panic.zig");
const pid = @import("pid.zig");

const ArrayList = std.ArrayList;
const MemSet = mm.memory_set.MemorySet;
const MapPermission = mm.memory_set.MapPermission;
const MapPermissions = mm.memory_set.MapPermissions;
const TaskContext = @import("context.zig").TaskContext;

const BIG_STRIDE: usize = 1 << 16;
const TICKET: usize = 1 << 8;

pub const TaskStatus = enum {
    UnInit,
    Ready,
    Running,
    Zombie,
    Exited,
};

pub const TaskControlBlock = struct {
    const Children = ArrayList(*TaskControlBlock);

    pid: pid.PidHandle,
    last_schedule: usize,
    pass: usize,
    stride: usize,
    kernel_stack: pid.KernelStack,
    base_size: usize,
    ctx: TaskContext,
    trap_ctx_ppn: addr.PhysPageNum,
    status: TaskStatus,
    mem_set: MemSet,
    parent: ?*TaskControlBlock,
    children: Children,
    waiting: ?*TaskControlBlock, // 表明当前任务正在等待另一个任务结束
    exit_code: i32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.pid.deinit();
        self.kernel_stack.deinit();
        self.mem_set.deinit();
        self.children.deinit();
    }

    pub fn wait_for(self: *Self, task: *Self) void {
        if (
            self.is_waiting() and 
            self.waiting.?.pid.v != task.pid.v
        ) {
            panic.panic(
                "task({d}) is waiting for {d} but still try to wait {d}", 
            .{ self.pid.v, self.waiting.?.pid.v, task.pid.v }
            );
        }
        self.waiting = task;
    }

    pub fn stop_waiting(self: *Self) void {
        self.waiting = null;
    }

    pub fn is_waiting(self: *Self) bool {
        return self.waiting != null;
    }

    pub fn set_priority(self: *Self, prio: usize) void {
        self.stride = BIG_STRIDE / (TICKET * prio);
    }

    pub fn get_scheduled(self: *Self) void {
        _ = self;
    }

    pub fn end_scheduled(self: *Self) void {
        self.pass += self.stride;
    }

    pub fn is_wait_for(self: *const Self, task: *const Self) bool {
        var pwait = self.waiting;
        while (pwait) |wait| {
            if (wait.pid.v == task.pid.v) {
                return true;
            }
            pwait = wait.waiting;
        }
        return false;
    }

    pub fn cmp(_: void, lhs: *Self, rhs: *Self) std.math.Order {
        const lhs_is_waiting = lhs.is_waiting();
        const rhs_is_waiting = rhs.is_waiting();
        if (lhs_is_waiting and rhs_is_waiting) {
            if (lhs.is_wait_for(rhs)) {
                return std.math.Order.gt;
            } else if (rhs.is_wait_for(lhs)) {
                return std.math.Order.lt;
            } else {
                return std.math.order(lhs.pass, rhs.pass);
            }
        } else if (lhs_is_waiting) {
            return std.math.Order.gt;
        } else if (rhs_is_waiting) {
            return std.math.Order.lt;
        } else {
            return std.math.order(lhs.pass, rhs.pass);
        }
    }

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
            .pass = 1 << 5,
            .stride = BIG_STRIDE / TICKET,
            .last_schedule = 0,
            .kernel_stack = kernel_stack,
            .base_size = elf_mem_info.user_stack_top,
            .ctx = TaskContext.goto_trap_return(kernel_stack_top),
            .trap_ctx_ppn = trap_ctx_ppn,
            .status = TaskStatus.Ready,
            .mem_set = mem_set,
            .parent = null,
            .children = Children.init(allocator),
            .waiting = null,
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
        self.mem_set.deinit();
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
            .last_schedule = 0,
            .pass = 1 << 5,
            .stride = BIG_STRIDE / TICKET,
            .kernel_stack = kernel_stack,
            .base_size = self.base_size,
            .ctx = TaskContext.goto_trap_return(kernel_stack_top),
            .trap_ctx_ppn = trap_ctx_ppn,
            .status = TaskStatus.Ready,
            .mem_set = mem_set,
            .parent = self,
            .children = Children.init(self.allocator),
            .waiting = null,
            .exit_code = 0,
            .allocator = self.allocator,
        };
        // add child
        try self.children.append(task_control_block);
        task_control_block.get_trap_ctx().kernel_sp = kernel_stack_top;
        return task_control_block;
    }
};

