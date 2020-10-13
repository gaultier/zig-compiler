const ast = @import("ast.zig");
const std = @import("std.zig");

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
    },
    IntegerLiteral: usize,
};

pub const Emitter = struct {
    ops: std.ArrayList(Op),

    fn init(allocator: *std.mem.Allocator) Emitter {
        return Emitter{ .ops = std.ArrayList(Op).init(allocator) };
    }

    fn emit(ast: *Node) void {
        if (ast.castTag(.BuiltinPrint)) |builtinprint| {}
    }
};
