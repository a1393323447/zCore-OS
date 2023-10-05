const config = @import("config.zig");
const riscv = @import("riscv/lib.zig");

const console = @import("console.zig");

const TICKS_PER_SEC: usize = 100;
const MICRO_PER_SEC: usize = 100_0000;

pub fn get_time() usize {
    return riscv.regs.time.read();
}

pub fn get_time_us() usize {
    return get_time() / (config.CLOCK_FREQ / MICRO_PER_SEC);
}

pub fn set_next_trigger() void {
    const timer = get_time() + config.CLOCK_FREQ / TICKS_PER_SEC;
    riscv.sbi.set_timer(timer);
}
