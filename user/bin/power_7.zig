const std = @import("std");
const console = @import("../console.zig");

const LEN: usize = 100;

export fn main() callconv(.C) i32 {
    const p: u64 = 5;
    const m: u64 = 998244353;
    const iter: usize = 160001;
    var s = std.mem.zeroes([LEN]u64);
    var cur: usize = 0;
    s[cur] = 1;
    for (1..iter) |i| {
        const next: usize = if (cur + 1 == LEN) 0 else cur + 1;
        s[next] = s[cur] * p % m;
        cur = next;
        if (i % 10000 == 0) {
            console.stdout.print("power_7 [{}/{}]\n", .{i, iter});
        }
    }
    console.stdout.print("{}^{} = {}(MOD {})\n", .{ p, iter, s[cur], m });
    console.stdout.print("Test power_7 OK!\n", .{});
    return 0;
}
