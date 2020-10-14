const ast = @import("ast.zig");
const std = @import("std");
const Node = ast.Node;

pub const Register = enum {
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

    fn toString(r: Register) []const u8 {
        return switch (r) {
            .rax => "%rax",
            .rbx => "%rbx",
            .rcx => "%rcx",
            .rdx => "%rdx",
            .rbp => "%rbp",
            .rsp => "%rsp",
            .rsi => "%rsi",
            .rdi => "%rdi",
            .r8 => "%r8",
            .r9 => "%r9",
            .r10 => "%r10",
            .r11 => "%r11",
            .r12 => "%r12",
            .r13 => "%r13",
            .r14 => "%r14",
            .r15 => "%r15",
        };
    }
};

pub const Asm = struct {
    text_section: std.ArrayList(Op),
    data_section: std.ArrayList(Op),

    pub fn init(allocator: *std.mem.Allocator) Asm {
        return Asm{
            .text_section = std.ArrayList(Op).init(allocator),
            .data_section = std.ArrayList(Op).init(allocator),
        };
    }

    pub fn deinit(a: *Asm) void {
        a.text_section.deinit();
        a.data_section.deinit();
    }

    pub fn dump(a: Asm) void {
        std.debug.warn("\n.data\n", .{});
        for (a.data_section.items) |op| {
            switch (op) {
                .StringLabel => |stringLabel| {
                    std.debug.warn(".L{}: .asciz \"{}\"\n", .{ stringLabel.label_id, stringLabel.string });
                },
                else => unreachable,
            }
        }

        std.debug.warn("\n.text\n", .{});
        // FIXME: for now, hardcoded to one main section
        std.debug.warn(".globl _main\n_main:\n", .{});
        for (a.text_section.items) |op| {
            switch (op) {
                .Syscall => |syscall| {
                    std.debug.warn("\tmovq {}, %rax\n", .{syscall.syscall_number});

                    var i: u8 = 0;
                    while (i < syscall.cardinality) : (i += 1) {
                        std.debug.warn("\tmovq {}, {}\n", .{ syscall.args[i], @intToEnum(Register, @intCast(u4, i)).toString() });
                    }
                    std.debug.warn("\tsyscall\n", .{});

                    i = 0;
                    while (i < syscall.cardinality) : (i += 1) {
                        std.debug.warn("\tmovq 0, {}\n", .{@intToEnum(Register, @intCast(u4, i)).toString()});
                    }
                    std.debug.warn("\n", .{});
                },
                else => unreachable,
            }
        }
    }
};

pub const Op = union(enum) {
    Syscall: struct {
        syscall_number: usize,
        cardinality: u8,
        args: [8]usize,
    },
    IntegerLiteral: usize,
    StringLabel: struct {
        label_id: usize,
        string: []const u8,
    },
};

const stdin: usize = 0;
const stdout: usize = 1;
const stderr: usize = 2;

const syscall_exit_osx: usize = 0x2000001;
const syscall_write_osx: usize = 0x2000004;

pub const Emitter = struct {
    pub fn emit(node: *Node, allocator: *std.mem.Allocator) std.mem.Allocator.Error!Asm {
        var a = Asm.init(allocator);
        errdefer a.deinit();

        var label_id: usize = 0;

        if (node.castTag(.BuiltinPrint)) |builtinprint| {
            try a.text_section.append(Op{
                .Syscall = .{
                    .syscall_number = syscall_write_osx,
                    .cardinality = 3,
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
            });

            label_id += 1;
            try a.data_section.append(Op{
                .StringLabel = .{
                    .label_id = label_id,
                    .string = "true", // FIXME
                },
            });
        }

        try a.text_section.append(Op{
            .Syscall = .{
                .syscall_number = syscall_exit_osx,
                .cardinality = 1,
                .args = [8]usize{
                    0,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                },
            },
        });

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

    std.testing.expectEqual(@as(usize, 2), a.text_section.items.len); // FIXME

    a.dump();
    // std.testing.expectEqual(Op.Syscall{ .syscall_number = syscall_write_osx, .args = .{ stdout, 65, 1 } }, ops[0]); // FIXME
}
