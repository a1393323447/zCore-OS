const riscv = @import("riscv/lib.zig");
const console = @import("console.zig");

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    console.logger.err(fmt, args);
    riscv.sbi.shutdown();
}
