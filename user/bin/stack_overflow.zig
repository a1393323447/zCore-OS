const process = @import("../process.zig");
const console = @import("../console.zig");

fn overflow(d: usize) void {
    console.stdout.info("d = {d}", .{d});
    overflow(d + 1);
}

export fn main() callconv(.C) i32 {
    console.stdout.info("It should trigger segmentation fault!", .{});
    overflow(0);
    return 0;
}