const panic = @import("../panic.zig");
const task = @import("../task/lib.zig");
const loader = @import("../loader.zig");
const riscv = @import("../riscv/lib.zig");
const regs = riscv.regs;
const Sstatus = riscv.regs.sstatus.Sstatus;

const std = @import("std");

// symbol __alltraps is defined in trap.S
extern fn __alltraps() callconv(.Naked) void;
pub fn init() void {
    regs.stvec.write(@intFromPtr(&__alltraps), regs.stvec.TrapMode.Diret);
}

pub fn enable_timer_interrupt() void {
    regs.sie.set_timer();
}

comptime {
    if (@sizeOf(TrapContext) != 34 * 8) {
        @compileError("Failed");
    }
}

pub const TrapContext = extern struct {
    /// general regs[0..31]
    x: [32]usize,
    /// CSR sstatus
    sstatus: Sstatus,
    /// CSR sepc
    sepc: usize,

    const Self = @This();

    pub inline fn set_sp(self: *Self, sp: usize) void {
        self.x[2] = sp;
    }

    pub fn app_init_context(entry: usize, sp: usize) Self {
        var sstatus = regs.sstatus.read();
        regs.sstatus.set_spp(regs.sstatus.SPP.User);
        var ctx = Self {
            .x = std.mem.zeroes([32]usize),
            .sstatus = sstatus,
            .sepc = entry,
        };

        ctx.set_sp(sp);

        return ctx;
    }
};

pub export fn trap_handler(ctx: *TrapContext) *TrapContext {
    const scause = regs.scause.read();
    const stval = regs.stval.read();

    const sys = @import("../syscall/lib.zig");
    const console = @import("../console.zig");

    switch (scause.cause()) {
        .exception => |exception| switch (exception) {
            .UserEnvCall => {
                ctx.sepc += 4;
                const code = sys.syscall(ctx.x[17], [_]usize{ ctx.x[10], ctx.x[11], ctx.x[12] });
                ctx.x[10] = @intCast(code);
            },
            .StoreFault, .StorePageFault => {
                console.logger.warn(
                    "[kernel] PageFault in application, bad memory addr = 0x{x}, bad instruction addr = 0x{x}, core dumped.", 
                    .{ stval, ctx.sepc }
                );
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
        .interrupt => |interrupt| switch(interrupt) {
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

    return ctx;
}
