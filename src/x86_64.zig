const std = @import("std");
const parse = @import("parse.zig");
const Parser = parse.Parser;
const ast = @import("ast.zig");
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
            4 => .rcx,
            5 => .r8,
            6 => .r9,
            7 => .r10,
            8 => .r11,
            else => null, // TODO: Implement more
        };
    }
};

pub const Asm = struct {
    text_section: []Op,
    data_section: []Op,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(a: *Asm) void {
        a.arena.deinit();
    }

    pub fn dump(a: Asm, out: *std.io.Writer) std.os.WriteError!void {
        try out.print("\n.data\n", .{});
        for (a.data_section) |op| {
            switch (op) {
                .StringLabel => |stringLabel| {
                    try out.print(".L{}: .asciz \"{}\"\n", .{ stringLabel.label_id, stringLabel.string });
                },
                else => unreachable,
            }
        }

        try out.print("\n.text\n", .{});
        // FIXME: for now, hardcoded to one main section
        try out.print(".globl _main\n_main:\n", .{});
        for (a.text_section) |op| {
            switch (op) {
                .Syscall => |syscall| {
                    for (syscall.args) |arg, i| {
                        const register = Register.fnArg(@intCast(u16, i));
                        switch (arg) {
                            .IntegerLiteral => |integerLiteral| {
                                try out.print("\tmovq ${}, {}\n", .{
                                    integerLiteral,
                                    register.?.toString(),
                                });
                            },
                            .LabelAddress => |label_id| {
                                try out.print("\tleaq .L{}({}), {}\n", .{
                                    label_id,
                                    Register.rip.toString(),
                                    register.?.toString(),
                                });
                            },
                            else => unreachable,
                        }
                    }
                    try out.print("\tsyscall\n", .{});

                    for (syscall.args) |_, i| {
                        const register = Register.fnArg(@intCast(u16, i));
                        try out.print("\tmovq $0, {}\n", .{register.?.toString()});
                    }
                    try out.print("\n", .{});
                },
                else => unreachable,
            }
        }
    }
};

pub const Op = union(enum) {
    Syscall: struct {
        args: []Op,
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
    pub fn emit(nodes: []*Node, parser: Parser, allocator: *std.mem.Allocator) std.mem.Allocator.Error!Asm {
        var arena = std.heap.ArenaAllocator.init(allocator);

        var text_section = std.ArrayList(Op).init(&arena.allocator);
        defer text_section.deinit();
        var data_section = std.ArrayList(Op).init(&arena.allocator);
        defer data_section.deinit();

        var label_id: usize = 0;

        for (nodes) |node| {
            if (node.castTag(.BuiltinPrint)) |builtinprint| {
                label_id += 1;
                const label = Op{
                    .StringLabel = .{
                        .label_id = label_id,
                        .string = builtinprint.arg.getNodeSource(parser),
                    },
                };
                try data_section.append(label);

                var args = std.ArrayList(Op).init(&arena.allocator);
                defer args.deinit();
                try args.appendSlice(&[_]Op{
                    Op{ .IntegerLiteral = syscall_write_osx },
                    Op{ .IntegerLiteral = stdout },
                    Op{ .LabelAddress = label.StringLabel.label_id },
                    Op{ .IntegerLiteral = label.StringLabel.string.len },
                });
                try text_section.append(Op{ .Syscall = .{ .args = args.toOwnedSlice() } });
            }
        }

        var args = std.ArrayList(Op).init(&arena.allocator);
        defer args.deinit();
        try args.append(Op{ .IntegerLiteral = syscall_exit_osx });
        try args.append(Op{ .IntegerLiteral = 0 });
        try text_section.append(Op{ .Syscall = .{ .args = args.toOwnedSlice() } });

        return Asm{
            .text_section = text_section.toOwnedSlice(),
            .data_section = data_section.toOwnedSlice(),
            .arena = arena,
        };
    }
};

test "emit" {
    var parser = try Parser.init(" print(true)\t", std.testing.allocator);
    defer parser.deinit();

    const nodes = try parser.parse();
    defer parser.allocator.free(nodes);

    var a = try Emitter.emit(nodes, parser, std.testing.allocator);
    defer a.deinit();

    std.testing.expectEqual(@as(usize, 2), a.text_section.len);

    const write_syscall = a.text_section[0].Syscall;
    std.testing.expectEqual(syscall_write_osx, write_syscall.args[0].IntegerLiteral);

    const exit_syscall = a.text_section[1].Syscall;
    std.testing.expectEqual(syscall_exit_osx, exit_syscall.args[0].IntegerLiteral);

    try a.dump();
}
