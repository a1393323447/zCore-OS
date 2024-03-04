const console = @import("../console.zig");
const process = @import("../process.zig");

const MAX_CHILD: usize = 40;

export fn main() callconv(.C) i32 {
    _ = process.spawn("stride_1\x00");
    _ = process.spawn("stride_2\x00");
    _ = process.spawn("stride_4\x00");

    var exit_code: i32 = 0;
    _ = process.wait(&exit_code);
    _ = process.wait(&exit_code);
    _ = process.wait(&exit_code);

    return exit_code;
}
