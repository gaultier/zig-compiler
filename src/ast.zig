const std = @import("std");
const parse = @import("parse.zig");
const Parser = parse.Parser;

pub const TokenIndex = usize;

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
        return parser.source[first_token.start..last_token.end];
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

        pub fn Type(tag: Tag) type {
            return switch (tag) {
                .BoolLiteral => OneToken,
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
