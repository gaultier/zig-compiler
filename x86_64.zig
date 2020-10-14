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
    rip,

    fn toString(r: Register) []const u8 {
        return switch (r) {
            .rax => "%rax",
            .rbx => "%rbx",
            .rcx => "%rcx",
            .rdx => "%rdx",
            .rbp => "%rbp",
            .rsp => "%rsp",
            .rsi => "%rsi",
            .rip => "%rip",
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

    fn fnArg(position: u16) ?Register {
        return switch (position) {
            0 => .rax,
            1 => .rdi,
            2 => .rsi,
            3 => .rdx,
            else => null, // TODO: Implement more
        };
    }
};

pub const Asm = struct {
    text_section: std.ArrayList(Op),
    data_section: std.ArrayList(Op),
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: *std.mem.Allocator) Asm {
        return Asm{
            .text_section = std.ArrayList(Op).init(allocator),
            .data_section = std.ArrayList(Op).init(allocator),
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(a: *Asm) void {
        a.text_section.deinit();
        a.data_section.deinit();
        a.arena.deinit();
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
                    std.debug.warn("\tmovq ${}, {}\n", .{
                        syscall.syscall_number, Register.fnArg(@intCast(u16, 0)).?.toString(),
                    });

                    for (syscall.args.items) |arg, i| {
                        const register = Register.fnArg(@intCast(u16, i + 1));
                        switch (arg) {
                            .IntegerLiteral => |integerLiteral| {
                                std.debug.warn("\tmovq ${}, {}\n", .{
                                    integerLiteral,
                                    register.?.toString(),
                                });
                            },
                            .LabelAddress => |label_id| {
                                std.debug.warn("\tleaq .L{}({}), {}\n", .{
                                    label_id,
                                    Register.rip.toString(),
                                    register.?.toString(),
                                });
                            },
                            else => unreachable,
                        }
                    }
                    std.debug.warn("\tsyscall\n", .{});

                    for (syscall.args.items) |_, i| {
                        const register = Register.fnArg(@intCast(u16, i + 1));
                        std.debug.warn("\tmovq $0, {}\n", .{register.?.toString()});
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
        args: std.ArrayList(Op),
    },
    IntegerLiteral: usize,
    StringLabel: struct {
        label_id: usize,
        string: []const u8,
    },
    LabelAddress: usize,
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
            label_id += 1;
            try a.data_section.append(Op{
                .StringLabel = .{
                    .label_id = label_id,
                    .string = "true", // FIXME
                },
            });

            var args = std.ArrayList(Op).init(&a.arena.allocator);
            errdefer args.deinit();
            try args.appendSlice(&[_]Op{
                Op{ .IntegerLiteral = stdout },
                Op{ .LabelAddress = label_id },
                Op{ .IntegerLiteral = 4 }, // FIXME
            });
            try a.text_section.append(Op{
                .Syscall = .{
                    .syscall_number = syscall_write_osx,
                    .args = args,
                },
            });
        }

        var args = std.ArrayList(Op).init(&a.arena.allocator);
        errdefer args.deinit();
        try args.append(Op{ .IntegerLiteral = 0 });
        try a.text_section.append(Op{
            .Syscall = .{
                .syscall_number = syscall_exit_osx,
                .args = args,
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
