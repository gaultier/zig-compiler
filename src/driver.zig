const std = @import("std");
const parse = @import("parse.zig");
const emit = @import("x86_64.zig");
const Parser = parse.Parser;
const Emitter = emit.Emitter;

fn isSourceFileNameValid(file_name: []const u8) bool {
    return file_name.len > 3 and std.mem.endsWith(u8, file_name, ".kts");
}

fn getBaseSourceFileName(file_name: []const u8) []const u8 {
    return file_name[0 .. file_name.len - 4];
}

pub fn run(source_file_name: []const u8, allocator: *std.mem.Allocator) !void {
    switch (std.builtin.os.tag) {
        .macos => {},
        else => return error.UnsupportedOs,
    }
    switch (std.builtin.arch) {
        .x86_64 => {},
        else => return error.UnsupportedArchitecture,
    }

    if (!isSourceFileNameValid(source_file_name)) return error.InvalidSourceFile;

    const source = try std.fs.cwd().readFileAlloc(allocator, source_file_name, 1_000_000);
    defer allocator.free(source);

    var parser = try Parser.init(source_file_name, source, std.testing.allocator);
    defer parser.deinit();

    const stderr_file = std.io.getStdErr();
    const stderr = stderr_file.outStream();
    const nodes = try parser.testParse(stderr, stderr_file.isTty());
    defer parser.allocator.free(nodes);

    var a = try Emitter.emit(nodes, parser, std.testing.allocator);
    defer a.deinit();

    const base_file_name = getBaseSourceFileName(source_file_name);
    var asm_file_name = try std.fmt.allocPrint(allocator, "." ++ std.fs.path.sep_str ++ "{}.asm", .{base_file_name});
    defer allocator.free(asm_file_name);

    var asm_file = try std.fs.cwd().createFile(asm_file_name, .{});
    defer asm_file.close();

    try a.dump(asm_file.writer());

    // as
    var object_file_name = try std.fmt.allocPrint(allocator, "." ++ std.fs.path.sep_str ++ "{}.o", .{base_file_name});
    defer allocator.free(object_file_name);

    {
        const argv = [_][]const u8{ "/usr/bin/as", asm_file_name, "-o", object_file_name };
        const exec_result = try std.ChildProcess.exec(.{ .argv = &argv, .allocator = allocator });

        switch (exec_result.term) {
            .Exited => |code| if (code != 0) {
                std.debug.warn("`as` invocation failed: command=`{} {} {} {}` exit_code={} stdout={} stderr={}\n", .{ argv[0], argv[1], argv[2], argv[3], code, exec_result.stdout, exec_result.stderr });
                return error.AssemblerFailed;
            },
            else => {
                std.debug.warn("`as` invocation failed: command=`{} {} {} {}` exit_result={} stdout={} stderr={}\n", .{ argv[0], argv[1], argv[2], argv[3], exec_result.term, exec_result.stdout, exec_result.stderr });
                return error.AssemblerError;
            },
        }
    }

    // ld
    var exe_file_name = try allocator.dupe(u8, base_file_name);
    defer allocator.free(exe_file_name);

    {
        const argv = [_][]const u8{ "/usr/bin/ld", object_file_name, "-o", exe_file_name, "-lSystem" };
        const exec_result = try std.ChildProcess.exec(.{ .argv = &argv, .allocator = allocator });

        switch (exec_result.term) {
            .Exited => |code| if (code != 0) {
                std.debug.warn("`ld` invocation failed: command=`{} {} {} {}` exit_code={} stdout={} stderr={}\n", .{ argv[0], argv[1], argv[2], argv[3], code, exec_result.stdout, exec_result.stderr });
                return error.AssemblerFailed;
            },
            else => {
                std.debug.warn("`ld` invocation failed: command=`{} {} {} {}` exit_result={} stdout={} stderr={}\n", .{ argv[0], argv[1], argv[2], argv[3], exec_result.term, exec_result.stdout, exec_result.stderr });
                return error.AssemblerError;
            },
        }
    }
}
