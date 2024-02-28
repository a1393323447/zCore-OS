const std = @import("std");
const console = @import("console.zig");
const panic = @import("panic.zig");

const ArrayList = std.ArrayList;

const ExternOptions = std.builtin.ExternOptions;
const num_app_ptr = @extern([*]usize, ExternOptions{
    .name = "_num_app",
});

pub fn get_app_num() usize {
    return num_app_ptr[0];
}

pub fn get_app_data(app_id: usize) []u8 {
    const app_num = get_app_num();
    const app_start = num_app_ptr[1..app_num+2];
    const src: [*]u8 = @ptrFromInt(app_start[app_id]);
    const size = app_start[app_id + 1] - app_start[app_id];
    return src[0..size];
}

extern fn _app_names() noreturn;
var APP_NAMES: ArrayList([]u8) = undefined;
pub fn init_app_name(allocator: std.mem.Allocator) !void {
    const app_num = get_app_num();
    var start: [*]u8 = @ptrFromInt(@intFromPtr(&_app_names));
    APP_NAMES = ArrayList([]u8).init(allocator);
    for (0..app_num) |_| {
        var i: usize = 0;
        var end = start;
        while (end[i] != 0) {
            i += 1;
        }
        try APP_NAMES.append(start[0..i]);
        start = @ptrCast(&end[i + 1]);
    }
}

pub fn get_app_data_by_name(name: []const u8) ?[]u8 {
    for (APP_NAMES.items, 0..) |app_name, i| {
        if (std.mem.eql(u8, app_name, name)) {
            return get_app_data(i);
        }
    }
    return null;
}

pub fn list_apps() void {
    console.logger.info("**** APPS ****", .{});
    for (APP_NAMES.items) |app| {
        console.logger.info("{s}", .{app});
    }
    console.logger.info("**************", .{});
}

pub fn init(allocator: std.mem.Allocator) void {
    init_app_name(allocator) catch |e| panic.panic("Failed to init load: {}", .{e});
    list_apps();
}
