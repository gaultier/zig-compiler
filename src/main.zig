const std = @import("std");
const run = @import("driver.zig").run;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    var args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    const file_name = if (args.len == 2) args[1] else {
        try std.io.getStdOut().outStream().print("{} <source file>\n", .{args[0]});
        return;
    };

    try run(file_name, allocator);
}
