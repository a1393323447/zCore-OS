pub const m = @import("main.zig");

const Self = @This();

test {
    const std = @import("std");
    std.testing.refAllDecls(Self);
}
