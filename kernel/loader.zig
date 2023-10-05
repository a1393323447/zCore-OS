const console = @import("console.zig");
const trap = @import("trap/lib.zig");
const panic = @import("panic.zig");
const config = @import("config.zig");

const std = @import("std");

const K: usize = 4096;
const USER_STACK_SIZE: usize = 2 * K;
const KERNEL_STACK_SIZE: usize = 2 * K;

pub var KERNEL_STACK: [config.MAX_APP_NUM]KernelStack = 
[_] KernelStack { KernelStack.zero_init() } ** config.MAX_APP_NUM;

pub var USER_STACK: [config.MAX_APP_NUM]UserStack = 
[_] UserStack { UserStack.zero_init() } ** config.MAX_APP_NUM;

const MAX_APP_NUM: usize = 16;
const APP_BASE_ADDRESS: usize = 0x80400000;
const APP_SIZE_LIMIT: usize = 0x20000;

const KernelStack align(1 * K) = struct {
    data: [KERNEL_STACK_SIZE]u8 align(1 * K),

    const Self = @This();

    pub fn zero_init() Self {
        return KernelStack { 
            .data = std.mem.zeroes([KERNEL_STACK_SIZE]u8) 
        };
    }

    pub fn get_sp(self: *const Self) usize {
        const ptr = &self.data[0];
        const sp = @intFromPtr(ptr) + KERNEL_STACK_SIZE;
        return sp;
    }

    pub fn push_context(self: *const Self, ctx: trap.TrapContext) *trap.TrapContext {
        const ctx_addr = self.get_sp() - @sizeOf(trap.TrapContext);
        const ctx_ptr: *trap.TrapContext = @ptrFromInt(ctx_addr);
        ctx_ptr.* = ctx;
        return ctx_ptr;
    }
};

const UserStack align(1 * K) = struct {
    data: [USER_STACK_SIZE]u8 align(1 * K),

    const Self = @This();

    pub fn zero_init() Self {
        return UserStack{ 
            .data = std.mem.zeroes([USER_STACK_SIZE]u8) 
        };
    }

    pub fn get_sp(self: *const Self) usize {
        const ptr = &self.data[0];
        const sp = @intFromPtr(ptr) + USER_STACK_SIZE;
        return sp;
    }
};

inline fn get_base_i(app_id: usize) usize {
    return APP_BASE_ADDRESS + app_id * APP_SIZE_LIMIT;
}

const ExternOptions = std.builtin.ExternOptions;
const num_app_ptr = @extern([*]usize, ExternOptions{
    .name = "_num_app",
});

pub fn get_app_num() usize {
    return num_app_ptr[0];
}

pub fn load_apps() void {
    const num_app = get_app_num();
    console.logger.info("Loading {} app", .{num_app});
    const app_start = num_app_ptr[1..(num_app + 2)];
    
    // clear i-cache first
    asm volatile ("fence.i");

    // load apps
    for (0..num_app) |i| {
        console.logger.info("Loading app {}", .{i});
        const base_i = get_base_i(i);
        console.logger.info("App {} base {x}", .{i, base_i});
        // clear region
        const area_ptr: *[APP_SIZE_LIMIT]u8 = @ptrFromInt(base_i);
        @memset(area_ptr[0..], 0);
        console.logger.info("Clean App {} region {x}~{x}", .{i, base_i, base_i + APP_SIZE_LIMIT});
        // load app from data section to memory
        const size = app_start[i + 1] - app_start[i];
        console.logger.info("App {} size {}", .{i, size});
        const src: [*]u8 = @ptrFromInt(app_start[i]);
        const dst = area_ptr;
        std.mem.copy(u8, dst[0..size], src[0..size]);
        console.logger.info("App {} loaded", .{i});
    }
    console.logger.info("All apps loaded", .{});
}

pub fn init_app_ctx(app_id: usize) usize {
    return @intFromPtr(KERNEL_STACK[app_id].push_context(
        trap.TrapContext.app_init_context(
            get_base_i(app_id), 
            USER_STACK[app_id].get_sp()
    )));
}
