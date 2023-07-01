const console = @import("console.zig");

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    console.logger.err(fmt, args);

    while (true) {
        asm volatile ("wfi");
    }
}
