const std = @import("std");

extern fn __restore() callconv(.Naked) void;

pub const TaskContext = struct {
    ra: usize,
    sp: usize,
    s: [12]usize,

    const Self = @This();

    pub fn zero() Self {
        return std.mem.zeroes(Self);
    }

    pub fn goto_restore(ksp: usize) Self {
        return Self {
            .ra = @intFromPtr(&__restore),
            .sp = ksp,
            .s = std.mem.zeroes([12]usize),
        };
    }
};
