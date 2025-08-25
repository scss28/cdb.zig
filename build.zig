const std = @import("std");
const Build = std.Build;
const fs = std.fs;
const mem = std.mem;
const panic = std.debug.panic;

const cdb_path: []const u8 = ".zig-cache/cdb";

pub fn addStep(b: *Build, name: []const u8) void {
    const cdb_step = b.step(name, "Create compile_commands.json");
    const step = b.allocator.create(Build.Step) catch panic("OOM", .{});
    step.* = .init(.{
        .id = .custom,
        .name = "install compile_commands.json",
        .makeFn = installCompileCommands,
        .owner = b,
    });
    cdb_step.dependOn(step);

    for (b.top_level_steps.values()) |tls| addCdbFlags(b, &tls.step);
}

fn addCdbFlags(b: *Build, step: *Build.Step) void {
    for (step.dependencies.items) |dep_step| addCdbFlags(b, dep_step);

    const artifact = step.cast(Build.Step.Compile) orelse return;
    for (artifact.root_module.link_objects.items) |obj| {
        const flags = switch (obj) {
            .c_source_files => |files| &files.flags,
            .c_source_file => |file| &file.flags,
            else => continue,
        };

        const new_flags = b.allocator.alloc(
            []const u8,
            flags.len + 2,
        ) catch panic("OOM", .{});

        new_flags[new_flags.len - 2] = "-gen-cdb-fragment-path";
        new_flags[new_flags.len - 1] = cdb_path;

        @memcpy(new_flags[0..flags.len], flags.*);
        flags.* = new_flags;
    }
}

fn installCompileCommands(step: *Build.Step, _: Build.Step.MakeOptions) !void {
    const b = step.owner;

    var combined: std.ArrayListUnmanaged(u8) = .empty;
    try combined.append(b.allocator, '[');

    var cdb_dir = try b.build_root.handle.openDir(cdb_path, .{
        .iterate = true,
    });
    defer cdb_dir.close();

    var it = cdb_dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        const bytes = try cdb_dir.readFileAlloc(
            b.allocator,
            entry.name,
            5_000_000,
        );

        try combined.appendSlice(b.allocator, bytes[0 .. bytes.len - 1]);
    }

    if (combined.items.len > 1) {
        // Change trailing comma to ']'.
        combined.items[combined.items.len - 1] = ']';

        b.build_root.handle.writeFile(.{
            .sub_path = "compile_commands.json",
            .data = combined.items,
        }) catch |err| panic(
            "error writing compile_commands.json ({s})",
            .{@errorName(err)},
        );
    }
}

pub fn build(_: *Build) void {
    @panic("cdb.zig is only meant to be used as a build tool");
}
