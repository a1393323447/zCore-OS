pub const Context = extern struct {
    // x8-x9, x19-x27
    xs: [12]usize = [_]usize{0}**12,
    sp: usize = 0,
    ip: usize = 0,
    const Self = @This();

    pub inline fn setStack(self: *Self, sp: usize) void {
        self.sp = sp;
    }
};
