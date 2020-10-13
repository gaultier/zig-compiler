const std = @import("std");
const lex = @import("lex.zig");
const ast = @import("ast.zig");
const Token = lex.Token;
const TokenIndex = ast.TokenIndex;
const Node = ast.Node;

pub const Error = error{ParseError} || std.mem.Allocator.Error;

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

    fn expectToken(p: *Parser, id: Token.Id) Error!TokenIndex {
        return (try p.expectTokenRecoverable(id)) orelse error.ParseError;
    }

    fn expectTokenRecoverable(p: *Parser, id: Token.Id) !?TokenIndex {
        const token = p.nextToken();
        if (p.token_ids[token] != id) {
            // try p.errors.append(p.gpa, .{
            //     .ExpectedToken = .{ .token = token, .expected_id = id },
            // });
            // go back so that we can recover properly
            // p.putBackToken(token);
            return null;
        }
        return token;
    }

    fn parsePrimaryType(p: *Parser) std.mem.Allocator.Error!?*Node {
        if (p.eatToken(.True)) |token| return p.createLiteral(.BoolLiteral, token);
        if (p.eatToken(.False)) |token| return p.createLiteral(.BoolLiteral, token);
        return null;
    }

    fn parseBuiltinPrint(p: *Parser) Error!?*Node {
        if (p.eatToken(Token.Id.BuiltinPrint)) |token| {
            _ = try p.expectToken(.LParen);
            const arg = (try p.parsePrimaryType()) orelse {
                // TODO: putBackToken
                return error.ParseError;
            };
            const rParen = try p.expectToken(.RParen);
            const result = try p.arena.allocator.create(Node.BuiltinPrint);
            errdefer p.arena.allocator.destroy(result);

            result.* = .{
                .base = .{ .tag = .BuiltinPrint },
                .mainToken = token,
                .arg = arg,
                .rParen = rParen,
            };
            return &result.base;
        } else return null;
    }

    fn createLiteral(p: *Parser, tag: ast.Node.Tag, token: TokenIndex) !*Node {
        const result = try p.arena.allocator.create(Node.OneToken);
        result.* = .{
            .base = .{ .tag = tag },
            .token = token,
        };
        return &result.base;
    }

    pub fn parse(p: *Parser) Error![]*Node {
        var list = std.ArrayList(*Node).init(p.allocator);
        defer list.deinit();

        while (true) {
            if (try p.parseBuiltinPrint()) |node| {
                try list.append(node);
                continue;
            }

            const next = p.token_ids[p.tok_i];
            switch (next) {
                .Eof => break,
                else => {
                    // try p.errors.append();
                    return error.ParseError;
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

// test "parsePrimaryType" {
//     var parser = try Parser.init(" true false  ", std.testing.allocator);
//     defer parser.deinit();

//     const nodes = try parser.parse();
//     defer parser.allocator.free(nodes);
//     std.testing.expectEqual(@as(usize, 2), nodes.len);

//     std.testing.expectEqual(Node.Tag.BoolLiteral, nodes[0].*.tag);

//     const nodeFalse = try parser.parse();
//     std.testing.expectEqual(Node.Tag.BoolLiteral, nodes[1].*.tag);
// }

test "parseBuiltinPrint" {
    var parser = try Parser.init(" print(true)", std.testing.allocator);
    defer parser.deinit();

    const nodes = try parser.parse();
    defer parser.allocator.free(nodes);
    std.testing.expectEqual(@as(usize, 1), nodes.len);

    var node = nodes[0];
    std.testing.expectEqual(Node.Tag.BuiltinPrint, node.tag);

    var builtinPrint = node.castTag(.BuiltinPrint).?;
    std.testing.expectEqual(@as(usize, 0), builtinPrint.mainToken);
    // var arg = builtinPrint.arg.castTag(.BoolLiteral).?;
    // std.testing.expectEqual(@as(usize, 7), arg.token);

    std.debug.warn("\n----\n", .{});
    node.dump(0);
}
