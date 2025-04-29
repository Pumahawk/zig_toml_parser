const std = @import("std");
const expect = std.testing.expect;

pub const ParseNode = struct {
    next: ?*ParseNode,
    value: TomplNode,
};

pub const TomplNodeType = enum {
    null_v,
};

pub const TomplNode = union(TomplNodeType) {
    null_v: void,
};

pub const ParsePipe = struct {
    allocator: std.mem.Allocator,
    head: ?*ParseNode,

    pub fn init(allocator: std.mem.Allocator) ParsePipe {
        return .{
            .allocator = allocator,
            .head = null,
        };
    }

    pub fn push(self: *ParsePipe, node: TomplNode) !void {
        const new_head = try self.allocator.create(ParseNode);
        new_head.* = ParseNode{
            .next = self.head,
            .value = node,
        };
        self.head = new_head;
    }

    pub fn pop(self: *ParsePipe) ?TomplNode {
        return if (self.head) |head| {
            const value = head.value;
            self.head = head.next;
            self.allocator.destroy(head);
            return value;
        } else null;
    }
};

test "ParsePipe memory operations" {
    const node = TomplNode{
        .null_v = {},
    };

    var pipe = ParsePipe.init(std.testing.allocator);
    try pipe.push(node);
    const node2 = pipe.pop().?;
    switch (node2) {
        .null_v => {},
        // else => unreachable,
    }
}

pub const TokenType = enum {
    comment,
    assign,
    table_head,
    table_key,
    table_value,
};

pub const Token = union {
    comment: []const u8,
    assign: void,
    table_head: []const u8,
    table_key: []const u8,
    table_value: []const u8,
};

pub const TokenizerStatus = enum {
    base,
    text_read,
    text_escape_read,
};

pub const TokenSource = fn () ?u8;

pub const Tokenizer = struct {
    allocator: std.mem.Allocator,
    status: TokenizerStatus,
    reader: fn () ?u8,

    pub fn init(allocator: std.mem.Allocator, source: TokenSource) Tokenizer {
        return .{
            .allocator = allocator,
            .status = TokenizerStatus.base,
            .source = source,
        };
    }

    pub fn next(self: Tokenizer) !?Token {
        return switch (self.status) {
            .base => self.baseNext(),
            .text_read, .text_escape_read => textNext(),
        };
    }

    fn baseNext() !?Token {
        // TODO
        return null;
    }

    fn textNext() !?Token {
        // TODO
        return null;
    }
};
