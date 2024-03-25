const console = @import("../console.zig");
const process = @import("../process.zig");

const std = @import("std");
const shared = @import("shared");

const co = shared.zcoroutine;

var HEAP_SPACE: [1024 * 1024]u8 = 
[_] u8 { 0 } ** (1024 * 1024);
var FIXED_BUF_ALLOC = std.heap.FixedBufferAllocator.init(&HEAP_SPACE);
const allocator = FIXED_BUF_ALLOC.allocator();

pub fn microTimestamp() i64 {
    return @bitCast(process.get_time_us());
}

pub fn sleep(t: u32) void {
    process.sleep(@intCast(t / std.time.ns_per_ms));
}

fn child(id: usize) void {
    console.stdout.info("child {} start!", .{ id });
    console.stdout.info("Sleep for {}s", .{ id });
    co.coSleep(@intCast(1000 * 1000 * id)) catch |err| {
        console.stdout.err("CoTest 0 Failed: {}", .{err});
        return;
    };
    console.stdout.info("child {} wake up", .{ id });
}

fn spawnChildren() void {
    var handles = std.ArrayList(*const co.CoHandle(void)).init(allocator);
    defer handles.deinit();

    for (0..10) |i| {
        const handle = co.coStart(child, .{@as(u32, @intCast(i))}, co.CoConfig{ .stack_size = 1024 * 64 }) catch |err| {
            console.stdout.err("CoTest 0 Failed: {}", .{err});
            return;
        };
        handles.append(handle) catch |err| {
            console.stdout.err("CoTest 0 Failed: {}", .{err});
            return;
        };
    }

    for (handles.items) |handle| {
        handle.Await() catch |err| {
            console.stdout.err("CoTest 0 Failed: {}", .{err});
            return;
        };
    }
}

pub fn cotest() !void {
    try co.coInit(allocator);
    spawnChildren();
}

export fn main() callconv(.C) i32 {
    cotest() catch |err| {
        console.stdout.err("CoTest 0 Failed: {}", .{err});
        return -1;
    };
    console.stdout.info("CoTest 0 Success!", .{});
    return 0;
}


