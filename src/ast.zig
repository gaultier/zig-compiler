const std = @import("std");
const parse = @import("parse.zig");
const lex = @import("lex.zig");
const Parser = parse.Parser;

pub const TokenIndex = usize;
const Token = lex.Token;

pub const Error = union(enum) {
    InvalidToken: InvalidToken,
    ExpectedToken: ExpectedToken,

    pub const InvalidToken = SingleTokenError("Invalid token '{}'");

    fn SingleTokenError(comptime msg: []const u8) type {
        return struct {
            const ThisError = @This();

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: []const Token.Id, stream: anytype) !void {
                const actual_token = tokens[self.token];
                return stream.print(msg, .{actual_token.symbol()});
            }
        };
    }

    pub const ExpectedToken = struct {
        token: TokenIndex,
        expected_id: Token.Id,

        pub fn render(self: *const ExpectedToken, tokens: []const Token.Id, stream: anytype) !void {
            const found_token = tokens[self.token];
            switch (found_token) {
                .Invalid => {
                    return stream.print("expected '{}', found invalid bytes", .{self.expected_id.symbol()});
                },
                else => {
                    const token_name = found_token.symbol();
                    return stream.print("expected '{}', found '{}'", .{ self.expected_id.symbol(), token_name });
                },
            }
        }
    };

    pub fn render(self: *const Error, tokens: []const Token.Id, stream: anytype) !void {
        switch (self.*) {
            .InvalidToken => |*x| return x.render(tokens, stream),
            .ExpectedToken => |*x| return x.render(tokens, stream),
        }
    }

    pub fn loc(self: *const Error) TokenIndex {
        switch (self.*) {
            .InvalidToken => |x| return x.token,
            .ExpectedToken => |x| return x.token,
        }
    }
};

pub const Node = struct {
    tag: Tag,

    pub fn castTag(base: *Node, comptime tag: Tag) ?*tag.Type() {
        if (base.tag == tag) {
            return @fieldParentPtr(tag.Type(), "base", base);
        }
        return null;
    }

    pub fn getNodeSource(node: *const Node, parser: Parser) []const u8 {
        const first_token = parser.token_locs[node.firstToken()];
        const last_token = parser.token_locs[node.lastToken()];
        return if (node.tag == .StringLiteral) parser.source[first_token.start + 1 .. last_token.end - 1] else parser.source[first_token.start..last_token.end];
    }

    pub fn firstToken(base: *const Node) TokenIndex {
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (base.tag == tag) {
                return @fieldParentPtr(tag.Type(), "base", base).firstToken();
            }
        }
        unreachable;
    }

    pub fn lastToken(base: *const Node) TokenIndex {
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (base.tag == tag) {
                return @fieldParentPtr(tag.Type(), "base", base).lastToken();
            }
        }
        unreachable;
    }

    pub const Tag = enum {
        BoolLiteral,
        BuiltinPrint,
        StringLiteral,

        pub fn Type(tag: Tag) type {
            return switch (tag) {
                .BoolLiteral, .StringLiteral => OneToken,
                .BuiltinPrint => BuiltinPrint,
            };
        }
    };

    pub const BuiltinPrint = struct {
        base: Node,
        arg: *Node,
        mainToken: TokenIndex,
        rParen: TokenIndex,

        pub fn firstToken(base: *const BuiltinPrint) TokenIndex {
            return base.mainToken;
        }

        pub fn lastToken(base: *const BuiltinPrint) TokenIndex {
            return base.rParen;
        }

        pub fn iterate(self: *const BuiltinPrint, index: usize) ?*Node {
            if (index < 1) return self.arg else return null;
        }
    };

    pub const OneToken = struct {
        base: Node,
        token: TokenIndex,

        pub fn firstToken(self: *const OneToken) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const OneToken) TokenIndex {
            return self.token;
        }

        pub fn iterate(self: *const OneToken, index: usize) ?*Node {
            return null;
        }
    };

    pub fn iterate(base: *Node, index: usize) ?*Node {
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (base.tag == tag) {
                return @fieldParentPtr(tag.Type(), "base", base).iterate(index);
            }
        }
        unreachable;
    }

    pub fn dump(self: *Node, indent: usize) void {
        {
            var i: usize = 0;
            while (i < indent) : (i += 1) {
                std.debug.warn(" ", .{});
            }
        }
        std.debug.warn("{}\n", .{@tagName(self.tag)});

        var child_i: usize = 0;
        while (self.iterate(child_i)) |child| : (child_i += 1) {
            child.dump(indent + 2);
        }
    }
};

pub const Location = struct {
    line: usize,
    column: usize,
    line_start: usize,
    line_end: usize,
};
