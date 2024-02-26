const std = @import("std");
const panic = @import("panic.zig");

pub fn assert(ok: bool, comptime fmt: []const u8, args: anytype) void {
    if (!ok) {
        if (@inComptime()) {
            @compileError(std.fmt.comptimePrint(fmt, args));
        } else {
            panic.panic(fmt, args);
        }
    }
}

const CmpFn = fn(left: anytype, right: anytype) bool;
pub fn assert_eq_cmp(left: anytype, right: anytype, comptime cmp: CmpFn, comptime loc: std.builtin.SourceLocation) void {
    assert(cmp(left, right), "{s}:{d}:{d}: left({}) != right({})", .{
        loc.file, loc.line, loc.column, 
        left, right
    });
}

fn basic_cmp(left: anytype, right: anytype) bool {
    return left == right;
}

pub fn assert_eq(left: anytype, right: anytype, comptime loc: std.builtin.SourceLocation) void {
    assert_eq_cmp(left, right, basic_cmp, loc);
}
