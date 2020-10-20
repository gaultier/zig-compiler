const std = @import("std");
const parse = @import("parse.zig");
const emit = @import("x86_64.zig");
const Parser = parse.Parser;
const Emitter = emit.Emitter;

pub fn run(file_name: []const u8, allocator: *std.mem.Allocator) !void {
    const source = try std.fs.cwd().readFileAlloc(allocator, file_name, 1_000_000);
    defer allocator.free(source);

    var parser = try Parser.init(source, std.testing.allocator);
    defer parser.deinit();

    const nodes = try parser.parse();
    defer parser.allocator.free(nodes);

    var a = try Emitter.emit(nodes, parser, std.testing.allocator);
    defer a.deinit();

    var asm_file_name = "test.asm";
    var asm_file = try std.fs.cwd().createFile(asm_file_name, .{});
    defer asm_file.close();
    try a.dump(asm_file.writer());
}
