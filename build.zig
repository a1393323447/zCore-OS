const std = @import("std");
const Mode = std.builtin.Mode;
const CodeModel = std.builtin.CodeModel;

const Step = std.build.Step;
const Module = std.build.Module;
const LazyPath = std.build.LazyPath;
const FileSource = std.build.FileSource;
const TestOptions = std.build.TestOptions;
const CompileStep = std.build.CompileStep;
const CreateModuleOptions = std.build.CreateModuleOptions;

const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;
const Cpu = Target.Cpu;
const CpuModel = Target.Cpu.Model;
const Os = Target.Os;
const Abi = Target.Abi;
const ObjectFormat = Target.ObjectFormat;

const user_linker_script_path = "user/linker.ld";
const kernel_linker_script_path = "kernel/linker.ld";

const coroutine_asm_files = [_][]const u8{
    "shared/zcoroutine/src/arch/riscv64/zcore/core.S",
};

const kernel_asm_files = [_][]const u8{
    "kernel/entry.S",
    "kernel/trap/trap.S",
    "kernel/task/switch.S",
    "kernel/link_app.S",
} ++ coroutine_asm_files;

const riscv64 = CrossTarget.fromTarget(Target{
    .cpu = Cpu.baseline(Cpu.Arch.riscv64),
    .os = Os{ .tag = Os.Tag.freestanding, .version_range = Os.VersionRange{ .none = {} } },
    .abi = Abi.eabi,
    .ofmt = ObjectFormat.elf,
});

// for debug option
var is_debug: bool = false;
var input_app_name: ?[]const u8 = null;

var string_buffer: [512]u8 = undefined;
fn format(comptime fmt: []const u8, args: anytype) []u8 {
    return std.fmt.bufPrint(&string_buffer, fmt, args) 
        catch |err| std.debug.panic("Error occured while formatting string: {}\n", .{err});
}

pub inline fn optimize(debug: bool) Mode {
    return if (debug) Mode.Debug else Mode.ReleaseSafe;
}

pub fn build(b: *std.build.Builder) void {
    init_options(b);
    // create shared module
    // it would be added in complie step
    const shared = create_shared_module(b);
    // zig build check: for checking syntax
    set_checking(b, shared);
    // zig build -DappName=APP_NAME
    set_build_user_app(b, shared);
    // zig build img: for building zcore-os.bin
    set_build_img(b, shared);
}

fn init_options(b: *std.build.Builder) void {
    is_debug = b.option(bool, "debug", "Enable debug mode") orelse false;
    input_app_name = b.option([]const u8, "appName", "App name");
}

fn create_shared_module(b: *std.build.Builder) *Module {
    const shared = b.addModule("shared", CreateModuleOptions{
        .source_file = FileSource.relative("shared/lib.zig"),
    });

    return shared;
}

fn set_build_img(b: *std.build.Builder, shared: *Module) void {
    const build_kernel_step = build_kernel(b, shared);

    const build_img = b.step("img", "Build zcore-os.bin");
    build_img.dependOn(build_kernel_step);
}

fn set_checking(b: *std.build.Builder, shared: *Module) void {
    // for checking syntax
    const do_check = b.step("check", "Check File");

    const check_kernel = b.addTest(TestOptions{
        .root_source_file = FileSource.relative("kernel/check.zig"),
    });
    check_kernel.addModule("shared", shared);
    
    config_compile_step(check_kernel, kernel_linker_script_path, &kernel_asm_files);

    do_check.dependOn(&check_kernel.step);
}

fn build_kernel(b: *std.build.Builder, shared: *Module) *Step {
    const kernel = b.addExecutable(std.build.ExecutableOptions{
        .name = "zcore-os",
        .root_source_file = std.build.FileSource.relative("kernel/main.zig"),
    });
    kernel.addModule("shared", shared);

    config_compile_step(kernel, kernel_linker_script_path, &kernel_asm_files);

    // for zig build cmd
    b.installArtifact(kernel);

    // emit bin file
    const emit_bin_file_step = emit_bin(b, kernel, "zcore-os.bin");

    return emit_bin_file_step;
}

fn set_build_user_app(b: *std.build.Builder, shared: *Module) void {
    const build_app_step = b.step("app", "Build user app `AppName`. ie. zig build app -DAppName=foo");
    if (input_app_name) |name| {
        const building_step = build_user_app(b, shared, name);
        build_app_step.dependOn(building_step);
        std.debug.print("Building app {s}\n", .{name});
    }
}

// TODO: change bin_main to executable and user_app to obj, then set default_panic in bin_main
fn build_user_app(b: *std.build.Builder, shared: *Module, app_name: []const u8) *Step {
    const user_asm_files = [_][]const u8{};
    const bin_asm_files = [_][]const u8{} ++ coroutine_asm_files;

    const bin_main = b.addObject(.{
        .name = "bin_main",
        .root_source_file = std.build.FileSource.relative("user/bin_main.zig"),
        .target = riscv64,
        .optimize = optimize(is_debug),
    });

    config_compile_step(bin_main, null, &bin_asm_files);

    bin_main.main_pkg_path = LazyPath.relative("user");
    bin_main.addModule("shared", shared);

    const user_app = b.addExecutable(std.build.ExecutableOptions{
        .name = app_name,
        .root_source_file = std.build.FileSource.relative(format("user/bin/{s}.zig", .{app_name})),
    });

    user_app.main_pkg_path = LazyPath.relative("user");
    user_app.addModule("shared", shared);
    user_app.addObject(bin_main);

    config_compile_step(user_app, user_linker_script_path, &user_asm_files);

    b.installArtifact(user_app);

    const emit_elf_step = emit_elf(b, user_app, app_name);
    // emit bin file
    const emit_bin_file_step = emit_bin(b, user_app, format("{s}.bin", .{app_name}));

    emit_bin_file_step.dependOn(emit_elf_step);

    return emit_bin_file_step;
}

fn config_compile_step(step: *CompileStep, comptime linker_script_path: ?[]const u8, comptime asm_file_paths: []const []const u8) void {
    // set target
    step.target = riscv64;
    // set opt level
    step.optimize = optimize(is_debug);
    // strip debug info if not in debug mode
    step.strip = !is_debug;

    // disable stack protector
    // stack protector unavailable without libC
    step.stack_protector = false;

    // https://github.com/ziglang/zig/issues/5558
    step.code_model = CodeModel.medium;

    for (asm_file_paths) |path| {
        const lpath = LazyPath.relative(path);
        step.addAssemblyFile(lpath);
    }

    if (linker_script_path) |path| {
        const linker_script_source = FileSource.relative(path);
        step.setLinkerScriptPath(linker_script_source);
    }
}

fn emit_bin(b: *std.build.Builder, source_exe: *CompileStep, install_name: []const u8) *Step {
    const objcopy = source_exe.addObjCopy(std.build.ObjCopyStep.Options{
        .format = std.build.ObjCopyStep.RawFormat.bin,
    });
    const copy_to_bin = b.addInstallBinFile(objcopy.getOutputSource(), install_name);
    return &copy_to_bin.step;
}

fn emit_elf(b: *std.build.Builder, source_exe: *CompileStep, install_name: []const u8) *Step {
    const copy_to_elf = b.addInstallFile(source_exe.getEmittedBin(), install_name);
    return &copy_to_elf.step;
}
