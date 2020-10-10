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

    fn init(source: []const u8, allocator: *std.mem.Allocator) !Parser {
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
        };
    }

    fn deinit(p: *Parser) void {
        p.allocator.free(p.token_ids);
        p.allocator.free(p.token_locs);
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

    fn parsePrimaryType(p: *Parser) !?*Node {
        if (p.eatToken(.True)) |token| return p.createLiteral(.BoolLiteral, token);
        if (p.eatToken(.False)) |token| return p.createLiteral(.BoolLiteral, token);
        return null;
    }

    fn createLiteral(p: *Parser, tag: ast.Node.Tag, token: TokenIndex) !*Node {
        const result = try p.allocator.create(Node.OneToken);
        result.* = .{
            .base = .{ .tag = tag },
            .token = token,
        };
        return &result.base;
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

    const nodeTrue = try parser.parsePrimaryType();
    // defer parser.allocator.destroy(nodeTrue.?.*);
    std.testing.expectEqual(Node.Tag.BoolLiteral, nodeTrue.?.*.tag);

    const nodeFalse = try parser.parsePrimaryType();
    // defer parser.allocator.destroy(nodeFalse.?.*);
    std.testing.expectEqual(Node.Tag.BoolLiteral, nodeFalse.?.*.tag);

    const nodeEof = try parser.parsePrimaryType();
    std.testing.expectEqual(@as(?*Node, null), nodeEof);
}
