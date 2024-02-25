const config = @import("../config.zig");
const console = @import("../console.zig");
const panic = @import("../panic.zig");
const task = @import("../task/lib.zig");
const loader = @import("../loader.zig");
const riscv = @import("../riscv/lib.zig");
const regs = riscv.regs;
const Sstatus = riscv.regs.sstatus.Sstatus;

const std = @import("std");

// symbol __restore is defined in trap.S
extern fn __restore() callconv(.Naked) void;
// symbol __alltraps is defined in trap.S
extern fn __alltraps() callconv(.Naked) void;
pub fn init() void {
    regs.stvec.write(@intFromPtr(&trap_from_kernel), regs.stvec.TrapMode.Diret);
}

pub fn enable_timer_interrupt() void {
    regs.sie.set_timer();
}

fn set_kernel_trap_entry() void {
    regs.stvec.write(@intFromPtr(&trap_from_kernel), regs.stvec.TrapMode.Diret);
}

fn set_user_trap_entry() void {
    regs.stvec.write(config.TRAMPOLINE, regs.stvec.TrapMode.Diret);
}

pub const TrapContext = extern struct {
    /// general regs[0..31]
    x: [32]usize,
    /// CSR sstatus
    sstatus: Sstatus,
    /// CSR sepc
    sepc: usize,
    kernel_satp: usize,
    kernel_sp: usize,
    trap_handler: usize,

    const Self = @This();

    pub inline fn set_sp(self: *Self, sp: usize) void {
        self.x[2] = sp;
    }

    pub fn app_init_context(
        entry: usize, 
        sp: usize, 
        kernel_satp: usize, 
        kernel_sp: usize, 
        trap_hd: usize
    ) Self {
        var sstatus = regs.sstatus.read();
        regs.sstatus.set_spp(regs.sstatus.SPP.User);
        var ctx = Self {
            .x = std.mem.zeroes([32]usize),
            .sstatus = sstatus,
            .sepc = entry,
            .kernel_satp = kernel_satp,
            .kernel_sp = kernel_sp,
            .trap_handler = trap_hd,
        };

        ctx.set_sp(sp);
        console.logger.info("set usp 0x{x}", .{sp});
        return ctx;
    }
};

pub export fn trap_handler() noreturn {
    set_kernel_trap_entry();
    const ctx = task.current_trap_ctx();
    const scause = regs.scause.read();
    const stval = regs.stval.read();

    const sys = @import("../syscall/lib.zig");

    switch (scause.cause()) {
        .exception => |exception| switch (exception) {
            .UserEnvCall => {
                ctx.sepc += 4;
                const code = sys.syscall(ctx.x[17], [_]usize{ ctx.x[10], ctx.x[11], ctx.x[12] });
                ctx.x[10] = @intCast(code);
            },
            .StoreFault, .StorePageFault => {
                console.logger.warn("[kernel] PageFault in application, bad memory addr = 0x{x}, bad instruction addr = 0x{x}, core dumped.", .{ stval, ctx.sepc });
                task.exit_current_and_run_next();
            },
            .IllegalInstruction => {
                console.logger.warn("[kernel] IllegalInstruction in application, kernel killed it.", .{});
                task.exit_current_and_run_next();
            },
            else => {
                panic.panic("Unsupported trap {}, stval = {x} !", .{
                    scause.cause(),
                    stval,
                });
            },
        },
        .interrupt => |interrupt| switch (interrupt) {
            .SupervisorTimer => {
                task.suspend_current_and_run_next();
            },
            else => {
                panic.panic("Unsupported trap {}, stval = {x} !", .{
                    scause.cause(),
                    stval,
                });
            },
        },
    }

    trap_return();
}

pub export fn trap_return() noreturn {
    set_user_trap_entry();
    const trap_ctx_ptr = config.TRAP_CONTEXT;
    const user_satp = task.current_user_token();
    const restore_va = @intFromPtr(&__restore) - @intFromPtr(&__alltraps) + config.TRAMPOLINE;
    asm volatile (
        \\ fence.i
        \\ jr %[restore_va]
        ::
        [restore_va] "{a0}" (restore_va),
        [user_satp] "{a1}" (user_satp),
        [trap_ctx_ptr] "r" (trap_ctx_ptr),
        : "memory"
    );
    panic.panic("trap return return!", .{});
}

pub export fn trap_from_kernel() noreturn {
    panic.panic("a trap from kernel!", .{});
}
