const std = @import("std");
const trap = @import("../trap/lib.zig");

pub const TaskContext = struct {
    ra: usize,
    sp: usize,
    s: [12]usize,

    const Self = @This();

    pub fn zero() Self {
        return std.mem.zeroes(Self);
    }

    pub fn goto_trap_return(ksp: usize) Self {
        return Self {
            .ra = @intFromPtr(&trap.trap_return),
            .sp = ksp,
            .s = std.mem.zeroes([12]usize),
        };
    }
};
