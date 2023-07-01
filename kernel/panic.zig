const console = @import("console.zig");

const EXIT_FAILURE_FLAG: u32 = 0x3333;
const EXIT_FAILURE: u32 = exit_code_encode(1); // Equals `exit(1)`.
const EXIT_RESET: u32 = 0x7777;

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    console.logger.err(fmt, args);
    
    asm volatile (
        \\ sw 0(%[addr]), %[code]
        :
        : [code] "r" (EXIT_FAILURE),
          [addr] "r" (0x100000),
    );

    while (true) {
        asm volatile ("wfi");
    }
}

/// Encode the exit code using EXIT_FAILURE_FLAG.
fn exit_code_encode(code: u32) u32 {
    return (code << 16) | EXIT_FAILURE_FLAG;
}
