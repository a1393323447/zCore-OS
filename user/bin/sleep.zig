const console = @import("../console.zig");
const process = @import("../process.zig");

export fn main() callconv(.C) i32 {
    process.sleep(1000);
    console.stdout.print("Test sleep OK!\n", .{});
    return 0;
}
