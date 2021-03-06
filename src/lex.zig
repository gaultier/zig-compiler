const std = @import("std");

pub const Token = struct {
    id: Id,
    loc: Loc,

    pub const Id = enum {
        BuiltinPrint,
        LParen,
        RParen,
        True,
        False,
        Identifier,
        LineComment,
        StringLiteral,
        Eof,
        Invalid,

        pub fn symbol(id: Id) []const u8 {
            return switch (id) {
                .BuiltinPrint => "print",
                .LParen => "(",
                .RParen => ")",
                .True => "true",
                .False => "false",
                .Identifier => "Identifier",
                .LineComment => "LineComment",
                .StringLiteral => "StringLiteral",
                .Eof => "EOF",
                .Invalid => "Invalid",
            };
        }
    };

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    const Keyword = struct { str: []const u8, id: Id };
    pub const keywords = [_]Keyword{
        Keyword{ .str = "true", .id = .True },
        Keyword{ .str = "false", .id = .False },
        Keyword{ .str = "print", .id = .BuiltinPrint },
    };

    pub fn getKeyword(bytes: []const u8) ?Id {
        for (keywords) |k| {
            if (std.mem.eql(u8, k.str, bytes)) return k.id;
        }
        return null;
    }
};

pub const Lex = struct {
    source: []const u8,
    index: usize,

    pub fn init(source: []const u8) Lex {
        return Lex{ .source = source, .index = 0 };
    }

    const State = enum {
        start,
        identifier,
        StringLiteral,
    };

    pub fn next(self: *Lex) Token {
        var result = Token{
            .id = .Eof,
            .loc = .{
                .start = self.index,
                .end = undefined,
            },
        };
        var state: State = .start;

        while (self.index < self.source.len) : (self.index += 1) {
            const c = self.source[self.index];

            switch (state) {
                .start => switch (c) {
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
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .identifier;
                        result.id = .Identifier;
                    },
                    '"' => {
                        result.id = .StringLiteral;
                        state = .StringLiteral;
                    },
                    else => {
                        result.id = .Invalid;
                        self.index += 1;
                        break;
                    },
                },
                .StringLiteral => switch (c) {
                    '"' => {
                        self.index += 1;
                        break;
                    },
                    else => {},
                },
                .identifier => switch (c) {
                    'a'...'z', 'A'...'Z', '_' => {},
                    else => {
                        if (Token.getKeyword(self.source[result.loc.start..self.index])) |id| {
                            result.id = id;
                        }
                        break;
                    },
                },
            }
        } else if (self.index == self.source.len) {
            switch (state) {
                .StringLiteral => result.id = .Invalid,
                else => {},
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

test "keywords" {
    testingExpectTokens(" true  false print ", &[_]TestToken{
        TestToken{ .id = .True, .start = 1, .end = 5 },
        TestToken{ .id = .False, .start = 7, .end = 12 },
        TestToken{ .id = .BuiltinPrint, .start = 13, .end = 18 },
    });
}

test "string" {
    testingExpectTokens(" \"foo\"", &[_]TestToken{
        TestToken{ .id = .StringLiteral, .start = 1, .end = 6 },
    });
}
