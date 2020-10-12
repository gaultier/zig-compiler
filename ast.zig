pub const TokenIndex = usize;

pub const Node = struct {
    tag: Tag,

    pub const Tag = enum {
        BoolLiteral,
        BuiltinPrint,
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
