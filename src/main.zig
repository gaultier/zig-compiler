const std = @import("std");

const parse = @import("parse.zig");
const emit = @import("x86_64.zig");
const Parser = parse.Parser;
const Emitter = emit.Emitter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    var parser = try Parser.init(" print(true)\t", std.testing.allocator);
    defer parser.deinit();

    const nodes = try parser.parse();
    defer parser.allocator.free(nodes);

    var node = nodes[0];

    var a = try Emitter.emit(node, parser, std.testing.allocator);
    defer a.deinit();

    a.dump();
}
