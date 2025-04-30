const std = @import("std");
const expect = std.testing.expect;
const print = std.debug.print;

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

pub const Token = union(TokenType) {
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

pub const Reader = struct {
    ptr: *anyopaque,
    nextFn: *const fn (ctx: *anyopaque) ?u8,

    pub fn next(self: *Reader) ?u8 {
        return self.nextFn(self.ptr);
    }
};

pub const TokenError = error{
    OutOfMemory,
    invalid_status,
    limited_buffer_size,
};

pub const Tokenizer = struct {
    allocator: std.mem.Allocator,
    status: TokenizerStatus,
    source: Reader,

    pub fn init(allocator: std.mem.Allocator, source: Reader) Tokenizer {
        return .{
            .allocator = allocator,
            .status = TokenizerStatus.base,
            .source = source,
        };
    }

    pub fn next(self: *Tokenizer) TokenError!?Token {
        return switch (self.status) {
            .base => self.baseNext(),
            else => TokenError.invalid_status,
        };
    }

    pub fn baseNext(self: *Tokenizer) TokenError!?Token {
        return while (self.source.next()) |char| {
            return if ((char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z'))
                self.nextKey(char)
            else
                TokenError.invalid_status;
        } else null;
    }

    pub fn nextKey(self: *Tokenizer, init_char: u8) TokenError!?Token {
        const n = comptime 100;
        var buf: [n]u8 = undefined;
        var i: u32 = 0;
        buf[i] = init_char;
        i += 1;
        return while (self.source.next()) |char| {
            if ((char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z') or char == '.') {
                if (i < n) {
                    buf[i] = char;
                    i += 1;
                } else {
                    break TokenError.limited_buffer_size;
                }
            } else if (char == ' ') {
                break Token{
                    .table_key = try self.allocator.dupe(u8, buf[0..i]),
                };
            }
        } else TokenError.invalid_status;
    }
};

test "tokenizer" {
    const input = "testo.ops ";
    var strs = StringSource{ .i = 0, .str = input };
    var tokenizer = Tokenizer.init(std.testing.allocator, strs.reader());

    const tok = tokenizer.next() catch |err| {
        print("err: {}\n", .{err});
        unreachable;
    };
    switch (tok.?) {
        .table_key => |key| {
            try expect(std.mem.eql(u8, key, "testo.ops"));
            std.testing.allocator.free(key);
        },
        else => unreachable,
    }
}

const StringSource = struct {
    i: usize,
    str: []const u8,

    fn reader(self: *StringSource) Reader {
        return Reader{
            .ptr = self,
            .nextFn = next,
        };
    }

    fn next(ptr: *anyopaque) ?u8 {
        var self: *StringSource = @ptrCast(@alignCast(ptr));
        if (self.i < self.str.len) {
            const c = self.str[self.i];
            self.i += 1;
            return c;
        } else {
            return null;
        }
    }
};
