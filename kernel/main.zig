const console = @import("console.zig");
// const loader = @import("loader.zig");
const panic = @import("panic.zig");
// const trap = @import("trap/lib.zig");
// const task = @import("task/lib.zig");
// const timer = @import("timer.zig");
const mm = @import("mm/lib.zig");

export fn _kmain() noreturn {
    clear_bss();

    print_logo();

    // trap.init();
    // task.init();

    // loader.load_apps();
    // trap.enable_timer_interrupt();
    // task.run_first_task();

    const std = @import("std");
    mm.heap_allocator.init_heap();

    const alloc = mm.heap_allocator.allocator;

    var arr = std.ArrayList(usize).init(alloc);
    for (0..2) |i| {
        arr.append(i) catch unreachable;
    }

    for (0..2) |i| {
        arr.items[i] += 1;
    }

    console.logger.info("Try deinit arr", .{});
    arr.deinit();
    console.logger.info("deinit done", .{});

    panic.panic("Unreachable in _kmain!\n", .{});
}

fn print_logo() void {
    const logo =
        \\  ________   ____                                  _____   ____       
        \\ /\_____  \ /\  _`\                               /\  __`\/\  _`\     
        \\ \/____//'/'\ \ \/\_\    ___   _ __    __         \ \ \/\ \ \,\L\_\   
        \\     //'/'  \ \ \/_/_  / __`\/\`'__\/'__`\ _______\ \ \ \ \/_\__ \   
        \\     //'/'___ \ \ \L\ \/\ \L\ \ \ \//\  __//\______\\ \ \_\ \/\ \L\ \ 
        \\     /\_______\\ \____/\ \____/\ \_\\ \____\/______/ \ \_____\ `\____\
        \\     \/_______/ \/___/  \/___/  \/_/ \/____/          \/_____/\/_____/
        \\
    ;
    console.logger.print(console.Color.Green.dye(logo ++ "\n"), .{});
}

fn clear_bss() void {
    const std = @import("std");
    const ExternOptions = std.builtin.ExternOptions;

    const sbss_ptr: [*]u8 = @extern([*]u8, ExternOptions{ .name = "sbss" });
    const ebss_ptr: [*]u8 = @extern([*]u8, ExternOptions{ .name = "ebss" });
    const sbss_addr = @intFromPtr(sbss_ptr);
    const ebss_addr = @intFromPtr(ebss_ptr);
    const bss_size = ebss_addr - sbss_addr;
    const bss_space: [*]u8 = @ptrFromInt(sbss_addr);

    for (bss_space[0..bss_size]) |*b| {
        b.* = 0;
    }
}
