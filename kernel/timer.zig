const config = @import("config.zig");
const riscv = @import("riscv/lib.zig");

const console = @import("console.zig");

const TICKS_PER_SEC: usize = 100;
const MSEC_PER_SEC: usize = 1000;
const MICRO_PER_SEC: usize = 100_0000;

/// read the `mtime` registe
pub fn get_time() usize {
    return riscv.regs.time.read();
}

/// get current time in microseconds
pub fn get_time_us() usize {
    return get_time() / (config.CLOCK_FREQ / MICRO_PER_SEC);
}

/// get current time in milliseconds
pub fn get_time_ms() usize {
    return get_time() / (config.CLOCK_FREQ / MSEC_PER_SEC);
}

/// set the next timer interrupt
pub fn set_next_trigger() void {
    const timer = get_time() + config.CLOCK_FREQ / TICKS_PER_SEC;
    riscv.sbi.set_timer(timer);
}
