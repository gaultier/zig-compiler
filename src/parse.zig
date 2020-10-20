const std = @import("std");
const lex = @import("lex.zig");
const ast = @import("ast.zig");
const Token = lex.Token;
const TokenIndex = ast.TokenIndex;
const Node = ast.Node;
const Location = ast.Location;
const AstError = ast.Error;

pub const Error = error{ParseError} || std.mem.Allocator.Error;

pub const Parser = struct {
    token_ids: []const Token.Id,
    token_locs: []const Token.Loc,
    source: []const u8,
    tok_i: usize,
    allocator: *std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    errors: std.ArrayList(AstError),

    pub fn init(source: []const u8, allocator: *std.mem.Allocator) std.mem.Allocator.Error!Parser {
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
            .errors = std.ArrayList(AstError).init(allocator),
        };
    }

    pub fn deinit(p: *Parser) void {
        p.allocator.free(p.token_ids);
        p.allocator.free(p.token_locs);
        p.errors.deinit();
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

    fn renderError(self: *Tree, parse_error: *const Error, stream: anytype) !void {
        return parse_error.render(self.token_ids, stream);
    }

    pub fn testParse(p: *Parser, errOut: anytype) ![]*Node {
        return p.parse() catch |_| {
            for (p.errors.items) |*parse_error| {
                const token = p.token_locs[parse_error.loc()];
                const loc = p.tokenLocation(0, parse_error.loc());

                try errOut.print("{}:{}: error: ", .{ loc.line + 1, loc.column + 1 });
                try parse_error.render(p.token_ids, errOut);
                try errOut.print("\n{}\n", .{source[loc.line_start..loc.line_end]});
            }
            try errOut.writeAll("\n");
        };
    }

    pub fn tokenLocation(self: *Parser, start_index: usize, token_index: TokenIndex) Location {
        return self.tokenLocationLoc(start_index, self.token_locs[token_index]);
    }

    /// Return the Location of the token relative to the offset specified by `start_index`.
    pub fn tokenLocationLoc(self: *Tree, start_index: usize, token: Token.Loc) Location {
        var loc = Location{
            .line = 0,
            .column = 0,
            .line_start = start_index,
            .line_end = self.source.len,
        };
        if (self.generated)
            return loc;
        const token_start = token.start;
        for (self.source[start_index..]) |c, i| {
            if (i + start_index == token_start) {
                loc.line_end = i + start_index;
                while (loc.line_end < self.source.len and self.source[loc.line_end] != '\n') : (loc.line_end += 1) {}
                return loc;
            }
            if (c == '\n') {
                loc.line += 1;
                loc.column = 0;
                loc.line_start = i + 1;
            } else {
                loc.column += 1;
            }
        }
        return loc;
    }

    fn expectToken(p: *Parser, id: Token.Id) Error!TokenIndex {
        return (try p.expectTokenRecoverable(id)) orelse error.ParseError;
    }

    fn expectTokenRecoverable(p: *Parser, id: Token.Id) !?TokenIndex {
        const token = p.nextToken();
        if (p.token_ids[token] != id) {
            try p.errors.append(.{
                .ExpectedToken = .{ .token = token, .expected_id = id },
            });
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

test "parseBuiltinPrint" {
    var parser = try Parser.init(" print(true)\t", std.testing.allocator);
    defer parser.deinit();

    const nodes = try parser.parse();
    defer parser.allocator.free(nodes);
    std.testing.expectEqual(@as(usize, 1), nodes.len);

    var node = nodes[0];
    std.testing.expectEqual(Node.Tag.BuiltinPrint, node.tag);

    var builtinPrint = node.castTag(.BuiltinPrint).?;
    var arg = builtinPrint.arg.castTag(.BoolLiteral).?;

    const arg_loc = parser.token_locs[arg.token];
    const first_loc = parser.token_locs[builtinPrint.firstToken()];
    const last_loc = parser.token_locs[builtinPrint.lastToken()];
    std.testing.expectEqualSlices(u8, "true", parser.source[arg_loc.start..arg_loc.end]);
    std.testing.expectEqualSlices(u8, "print(true)", parser.source[first_loc.start..last_loc.end]);
}

test "parseBuiltinPrint error" {
    var parser = try Parser.init(" print(true\t", std.testing.allocator);
    defer parser.deinit();

    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    const outStream = buffer.outStream();

    const res = parser.testParse(outStream);
    std.testing.expectError(error.ParseError, res);
    std.testing.expectEqual(@as(usize, 1), parser.errors.items.len);

    std.debug.warn("{}", .{buffer});

    // const err = parser.errors.items[0];
    // std.testing.expectEqual(AstError{ .ExpectedToken = .{ .token = 3, .expected_id = Token.Id.RParen } }, err);
}
