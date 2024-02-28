const shared = @import("shared");
const syscall = @import("syscall.zig");

// TODO: buffered write

const STDIN: usize = 0;
const STDOUT: usize = 1;

pub fn getchar() u8 {
    var c = [_]u8{0};
    _ = syscall.sys_read(STDIN, c[0..]);
    return c[0];
}


pub var stdout = Stdout.init(Context{});
const Context = struct {};
const WriteError = error{};
fn write(context: Context, bytes: []const u8) WriteError!usize {
    _ = context;
    const len = syscall.sys_write(STDOUT, bytes);
    return @intCast(len);
}
const Stdout = shared.console.Stdout(Context, WriteError, write);
