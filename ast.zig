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

        fn firstToken(base: *const Node) TokenIndex {
            return mainToken;
        }

        fn lastToken(base: *const Node) TokenIndex {
            return rParen;
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
    };
};
