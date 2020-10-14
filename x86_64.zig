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

pub const Asm = struct {
    text_section: std.ArrayList(Op),

    pub fn init(allocator: *std.mem.Allocator) Asm {
        return Asm{
            .text_section = std.ArrayList(Op).init(allocator),
        };
    }

    pub fn deinit(a: *Asm) void {
        a.text_section.deinit();
    }

    pub fn dump(a: Asm) void {
        std.debug.warn("\n.text\n", .{});
        // FIXME: for now, hardcoded to one main section
        std.debug.warn(".globl _main\n_main:\n", .{});
        for (a.text_section.items) |op| {
            switch (op) {
                .Syscall => |syscall| {
                    std.debug.warn("\tmovq %rax, {}\n", .{syscall.syscall_number});
                    std.debug.warn("\tmovq %rdi, {}\n", .{syscall.args[0]});
                    std.debug.warn("\tmovq %rsi, {}\n", .{syscall.args[1]});
                    std.debug.warn("\tmovq %rdx, {}\n", .{syscall.args[2]});
                },
                else => unreachable,
            }
        }
    }
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
    pub fn emit(node: *Node, allocator: *std.mem.Allocator) std.mem.Allocator.Error!Asm {
        var a = Asm.init(allocator);
        errdefer a.deinit();

        if (node.castTag(.BuiltinPrint)) |builtinprint| {
            try a.text_section.append(Op{
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

        return a;
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

    var a = try Emitter.emit(node, std.testing.allocator);
    defer a.deinit();

    std.testing.expectEqual(@as(usize, 1), a.text_section.items.len); // FIXME

    a.dump();
    // std.testing.expectEqual(Op.Syscall{ .syscall_number = syscall_write_osx, .args = .{ stdout, 65, 1 } }, ops[0]); // FIXME
}
