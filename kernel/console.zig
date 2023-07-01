const sbi = @import("riscv/lib.zig").sbi;
const shared = @import("shared");

pub const Color = shared.console.Color;
pub var logger = Stdout.init(Context{});

const Context = struct {};
const WriteError = error{};
fn write(context: Context, bytes: []const u8) WriteError!usize {
    _ = context;
    for (bytes) |byte| {
        sbi.console_putchar(byte);
    }

    return bytes.len;
}
const Stdout = shared.console.Stdout(Context, WriteError, write);
