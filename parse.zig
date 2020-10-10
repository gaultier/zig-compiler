const std = @import("std");
const lex = @import("lex");

const Parser = struct {
    token_ids: []const Token.Id,
    token_locs: []const Token.Loc,
    source: []const u8,
    tok_i: usize,
    allocator: std.mem.Allocator,

    fn init(source: []const u8, allocator: std.mem.Allocator) !Parser {
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
};
