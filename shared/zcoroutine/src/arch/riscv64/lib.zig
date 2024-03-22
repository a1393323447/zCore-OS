const OsTag = @import("std").Target.Os.Tag;
const zcore = @import("zcore/context.zig");

const os = @import("builtin").target.os.tag;

pub const Context: type = switch (os) {
    OsTag.freestanding => zcore.Context,
    else => @compileError("unsupport os " ++ @tagName(os)),
};
