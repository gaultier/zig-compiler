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

pub fn run(file_name: []const u8, allocator: *std.mem.Allocator) !void {
    if (!isSourceFileNameValid(file_name)) return error.InvalidSourceFile;

    const source = try std.fs.cwd().readFileAlloc(allocator, file_name, 1_000_000);
    defer allocator.free(source);

    var parser = try Parser.init(source, std.testing.allocator);
    defer parser.deinit();

    const nodes = try parser.parse();
    defer parser.allocator.free(nodes);

    var a = try Emitter.emit(nodes, parser, std.testing.allocator);
    defer a.deinit();

    const base_file_name = getBaseSourceFileName(file_name);

    var asm_file_name = try allocator.alloc(u8, base_file_name.len + 4);
    defer allocator.free(asm_file_name);
    std.mem.copy(u8, asm_file_name[0..], base_file_name[0..]);
    std.mem.copy(u8, asm_file_name[base_file_name.len..], ".asm");

    var asm_file = try std.fs.cwd().createFile(asm_file_name, .{});
    defer asm_file.close();
    try a.dump(asm_file.writer());
}
