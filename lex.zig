const std = @import("std");

const Token = struct {
    id: Id,
    loc: Loc,

    const Id = enum {
        BuiltinPrint, LParen, RParen, True, False, Eof, Invalid
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

const Lex = struct {
    source: []const u8,
    index: usize,

    pub fn init(source: []const u8) Lex {
        return Lex{ .source = source, .index = 0 };
    }

    pub fn next(self: *Lex) Token {
        var result = Token{
            .id = .Eof,
            .loc = .{
                .start = self.index,
                .end = undefined,
            },
        };

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

test "empty source" {
    var lex = Lex.init("");
    std.testing.expectEqual(lex.next().id, .Eof);
}

test "whitespace source" {
    var lex = Lex.init(" \t \n \r ");
    std.testing.expectEqual(lex.next().id, .Eof);
}
