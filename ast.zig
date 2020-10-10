pub const TokenIndex = usize;

pub const Node = struct {
    tag: Tag,

    pub const Tag = enum {
        BoolLiteral,
        BuiltinPrint,
    };

    pub const BuiltinPrint = struct {
        arg: Node,
        mainToken: TokenIndex,
        rParen: TokenIndex,

        fn firstToken(base: *const Node) TokenIndex {
            return mainToken;
        }

        fn lastToken(base: *const Node) TokenIndex {
            return rParen;
        }
    };
};
