const ast = @import("ast.zig");
const std = @import("std");
const Node = ast.Node;

pub const Registers = enum {
    rax,
    rbx,
    rcx,
    rdx,
    rbp,
    rsp,
    rsi,
    rdi,
    r8,
    r9,
    r10,
    r11,
    r12,
    r13,
    r14,
    r15,
};

pub const Op = union(enum) {
    Syscall: struct {
        syscall_number: usize,
        args: [8]usize,
    },
    IntegerLiteral: usize,
};

const stdin: usize = 0;
const stdout: usize = 1;
const stderr: usize = 2;

const syscall_write_osx: usize = 0x2000004;

pub const Emitter = struct {
    pub fn emit(node: *Node, allocator: *std.mem.Allocator) std.mem.Allocator.Error![]Op {
        var ops = std.ArrayList(Op).init(allocator);
        defer ops.deinit();

        if (node.castTag(.BuiltinPrint)) |builtinprint| {
            try ops.append(Op{
                .Syscall = .{
                    .syscall_number = syscall_write_osx,
                    .args = [8]usize{
                        stdout,
                        65, // FIXME
                        1, // FIXME
                        undefined,
                        undefined,
                        undefined,
                        undefined,
                        undefined,
                    },
                },
            }); // FIXME: linux?
        }

        return ops.toOwnedSlice();
    }
};

test "emit" {
    const parse = @import("parse.zig");
    const Parser = parse.Parser;

    var parser = try Parser.init(" print(true)\t", std.testing.allocator);
    defer parser.deinit();

    const nodes = try parser.parse();
    defer parser.allocator.free(nodes);

    var node = nodes[0];

    const ops = try Emitter.emit(node, std.testing.allocator);
    defer std.testing.allocator.free(ops);

    std.testing.expectEqual(@as(usize, 1), ops.len); // FIXME
    // std.testing.expectEqual(Op.Syscall{ .syscall_number = syscall_write_osx, .args = .{ stdout, 65, 1 } }, ops[0]); // FIXME
}
