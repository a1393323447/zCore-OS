const riscv = @import("riscv/lib.zig");
const console = @import("console.zig");

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    console.logger.err(fmt, args);

    // 这里不能使用 sbi 进行退出
    while (true) {
        asm volatile ("wfi");
    }
}
