const process = @import("../process.zig");
const console = @import("../console.zig");

export fn main() callconv(.C) i32 {
    const addr = 0x10000000;
    var success = process.mmap(addr, 4096 * 2, 3);
    if (success != 0) return -1;
    const buf: [*]u8 = @ptrFromInt(addr);
    for (0..4096*2) |i| {
        buf[i] = @intCast(i % 256);
    }
    console.stdout.info("mmap success", .{});

    success = process.munmap(addr, 4096);
    if (success != 0) return -1;

    console.stdout.info("munmap success", .{});

    for (0..4096) |i| {
        buf[i + 4096] = @intCast(i % 256);
    }

    console.stdout.info("This programe should be killed by kernel", .{});
    for (0..4096) |i| {
        buf[i] = @intCast(i % 256);
    }

    console.stdout.info("munmap_0 failed", .{});
    return 0;
}
