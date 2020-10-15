const std = @import("std");

const parse = @import("parse.zig");
const emit = @import("x86_64.zig");
const Parser = parse.Parser;
const Emitter = emit.Emitter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    var args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    const file_name = if (args.len == 2) args[1] else {
        try std.io.getStdOut().outStream().print("{} <source file>\n", .{args[0]});
        return;
    };

    const source = try std.fs.cwd().readFileAlloc(allocator, file_name, 1_000_000);
    defer allocator.free(source);

    var parser = try Parser.init(source, std.testing.allocator);
    defer parser.deinit();

    const nodes = try parser.parse();
    defer parser.allocator.free(nodes);

    var node = nodes[0];

    var a = try Emitter.emit(node, parser, std.testing.allocator);
    defer a.deinit();

    a.dump();
}
