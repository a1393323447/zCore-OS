const console = @import("../console.zig");
const process = @import("../process.zig");

export fn main() callconv(.C) i32 {
    console.stdout.info("getpid Ok! pid = {d}", .{process.getpid()});
    return 0;
}
