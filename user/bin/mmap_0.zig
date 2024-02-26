const process = @import("../process.zig");
const console = @import("../console.zig");

export fn main() callconv(.C) i32 {
    const addr = 0x10000000;
    const success = process.mmap(addr, 4096, 3);
    if (success == 0) {
        console.stdout.info("map 0x{x} success", .{addr});
        const buf: [*]u8 = @ptrFromInt(addr);
        const mapped_mem = buf[0..4096];
        for (0..4096) |i| {
            mapped_mem[i] = @intCast(i % 256);
        }
        for (mapped_mem, 0..) |byte, i| {
            if (byte != @as(u8, @intCast(i % 256))) {
                console.stdout.info("error: buf[{d}] != {d}", .{i, byte});
                return -1;
            }
        }
        console.stdout.info("mmap_0 success", .{});
        return 0;
    } else {
        console.stdout.err("mmap_0 failed", .{});
        return -1;
    }
}
