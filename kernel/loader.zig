const std = @import("std");

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

