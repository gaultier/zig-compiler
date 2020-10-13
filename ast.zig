const std = @import("std");

pub const TokenIndex = usize;

pub const Node = struct {
    tag: Tag,

    pub fn castTag(base: *Node, comptime tag: Tag) ?*tag.Type() {
        if (base.tag == tag) {
            return @fieldParentPtr(tag.Type(), "base", base);
        }
        return null;
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

        fn firstToken(base: *const BuiltinPrint) TokenIndex {
            return mainToken;
        }

        fn lastToken(base: *const BuiltinPrint) TokenIndex {
            return rParen;
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
