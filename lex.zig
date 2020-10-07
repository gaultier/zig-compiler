const std = @import("std");

pub const Token = struct {
    id: Id,
    loc: Loc,

    pub const Id = enum {
        BuiltinPrint, LParen, RParen, True, False, Identifier, Eof, Invalid
    };

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    const Keyword = struct { str: []const u8, id: Id };
    pub const keywords = []Keyword{
        Keyword{ .str = "true", .id = .True },
        Keyword{ .str = "false", .id = .False },
        Keyword{ .str = "@print", .id = .BuiltinPrint },
    };
};

pub const Lex = struct {
    source: []const u8,
    index: usize,

    pub fn init(source: []const u8) Lex {
        return Lex{ .source = source, .index = 0 };
    }

    const State = enum {
    .start,
    .identifier,
    };

    pub fn next(self: *Lex) Token {
        var result = Token{
            .id = .Eof,
            .loc = .{
                .start = self.index,
                .end = undefined,
            },
        };
        var state : State = .start;

        while (self.index < self.source.len) : (self.index += 1) {
            const c = self.source[self.index];

            switch (c) {
                ' ', '\n', '\t', '\r' => {
                    result.loc.start = self.index + 1;
                },
                '(' => {
                    result.id = .LParen;
                    self.index += 1;
                    break;
                },
                ')' => {
                    result.id = .RParen;
                    self.index += 1;
                    break;
                },
                // 'a'..'z', 'A'..'Z', '_' => {
        // state = .identifier;
        // result.id = .Identifier;
                // },
                else => {
                    result.id = .Invalid;
                    self.index += 1;
                    break;
                },
            }
        }
        result.loc.end = self.index;
        return result;
    }
};

const TestToken = struct {
    id: Token.Id,
    start: usize,
    end: usize,
};

fn testingExpectTokens(source: []const u8, tokens: []const TestToken) void {
    var lex = Lex.init(source);

    for (tokens) |testToken| {
        const t = lex.next();
        std.testing.expectEqual(testToken.id, t.id);
        std.testing.expectEqual(testToken.start, t.loc.start);
        std.testing.expectEqual(testToken.end, t.loc.end);
    }
}

test "empty source" {
    testingExpectTokens("", &[_]TestToken{
        TestToken{ .id = .Eof, .start = 0, .end = 0 },
    });
}

test "whitespace source" {
    testingExpectTokens(" \t  \n\r ", &[_]TestToken{
        TestToken{ .id = .Eof, .start = 7, .end = 7 },
    });
}

test "parens" {
    testingExpectTokens(" \t( \n)\r ", &[_]TestToken{
        TestToken{ .id = .LParen, .start = 2, .end = 3 },
        TestToken{ .id = .RParen, .start = 5, .end = 6 },
        TestToken{ .id = .Eof, .start = 8, .end = 8 },
    });
}
