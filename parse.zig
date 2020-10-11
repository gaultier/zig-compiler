const std = @import("std");
const lex = @import("lex.zig");
const ast = @import("ast.zig");
const Token = lex.Token;
const TokenIndex = ast.TokenIndex;
const Node = ast.Node;

const Parser = struct {
    token_ids: []const Token.Id,
    token_locs: []const Token.Loc,
    source: []const u8,
    tok_i: usize,
    allocator: *std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    // errors: std.ArrayListUnmanaged(AstError),

    fn init(source: []const u8, allocator: *std.mem.Allocator) std.mem.Allocator.Error!Parser {
        var token_ids = std.ArrayList(Token.Id).init(allocator);
        defer token_ids.deinit();
        try token_ids.ensureCapacity(source.len / 8); // Estimate

        var token_locs = std.ArrayList(Token.Loc).init(allocator);
        defer token_locs.deinit();
        try token_locs.ensureCapacity(source.len / 8);

        var lexer = lex.Lex.init(source);
        while (true) {
            const token = lexer.next();
            try token_ids.append(token.id);
            try token_locs.append(token.loc);
            if (token.id == .Eof) break;
        }

        return Parser{
            .tok_i = 0,
            .token_ids = token_ids.toOwnedSlice(),
            .token_locs = token_locs.toOwnedSlice(),
            .source = source,
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    fn deinit(p: *Parser) void {
        p.allocator.free(p.token_ids);
        p.allocator.free(p.token_locs);
        p.arena.deinit();
    }

    fn eatToken(p: *Parser, id: Token.Id) ?TokenIndex {
        return if (p.token_ids[p.tok_i] == id) p.nextToken() else null;
    }

    fn nextToken(p: *Parser) TokenIndex {
        const result = p.tok_i;
        p.tok_i += 1;
        std.debug.assert(p.token_ids[result] != .LineComment);
        if (p.tok_i >= p.token_ids.len) return result;

        while (true) {
            if (p.token_ids[p.tok_i] != .LineComment) return result;
            p.tok_i += 1;
        }
    }

    fn parsePrimaryType(p: *Parser) std.mem.Allocator.Error!?*Node {
        if (p.eatToken(.True)) |token| return p.createLiteral(.BoolLiteral, token);
        if (p.eatToken(.False)) |token| return p.createLiteral(.BoolLiteral, token);
        return null;
    }

    fn createLiteral(p: *Parser, tag: ast.Node.Tag, token: TokenIndex) !*Node {
        const result = try p.arena.allocator.create(Node.OneToken);
        result.* = .{
            .base = .{ .tag = tag },
            .token = token,
        };
        return &result.base;
    }

    pub fn parse(p: *Parser) std.mem.Allocator.Error![]*Node {
        var list = std.ArrayList(*Node).init(p.allocator);
        defer list.deinit();

        while (true) {
            if (try p.parsePrimaryType()) |node| {
                try list.append(node);
                continue;
            }

            const next = p.token_ids[p.tok_i];
            switch (next) {
                .Eof => break,
                else => {
                    // try p.errors.append();
                    break;
                },
            }
        }
        return list.toOwnedSlice();
    }
};

test "eatToken" {
    var parser = try Parser.init(" true false  ", std.testing.allocator);
    defer parser.deinit();

    std.testing.expectEqual(@as(?usize, 0), parser.eatToken(Token.Id.True));
    std.testing.expectEqual(@as(?usize, 1), parser.eatToken(Token.Id.False));
    std.testing.expectEqual(@as(?usize, null), parser.eatToken(Token.Id.BuiltinPrint));
}

test "parsePrimaryType" {
    var parser = try Parser.init(" true false ( ", std.testing.allocator);
    defer parser.deinit();

    const nodes = try parser.parse();
    defer parser.allocator.free(nodes);
    std.testing.expectEqual(@as(usize, 2), nodes.len);

    std.testing.expectEqual(Node.Tag.BoolLiteral, nodes[0].*.tag);

    const nodeFalse = try parser.parse();
    std.testing.expectEqual(Node.Tag.BoolLiteral, nodes[1].*.tag);
}
