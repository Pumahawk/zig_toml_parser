const std = @import("std");
const expect = std.testing.expect;
const print = std.debug.print;
const automa = @import("automa.zig");

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
    InvalidBufferAccess,
    OutOfMemory,
    invalid_status,
    limited_buffer_size,
};

pub const GivenToken = struct { ?u8, ?Token };

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
            return if (isQuoteChar(char) or isValidKeyChar(char)) {
                return if (try self.nextKey(char)) |token_tuple| {
                    _, const token = token_tuple;
                    return token;
                } else null;
            } else {
                return TokenError.invalid_status;
            };
        } else null;
    }

    pub fn nextKey(self: *Tokenizer, init_char: u8) TokenError!?GivenToken {
        var buf: [100]u8 = undefined;
        var i: usize = 0;
        var chart_opt: ?u8 = init_char;
        const statuses = enum {
            text,
            quoted_text,
        };
        var status = statuses.text;
        var open_quote: ?u8 = null;
        return while (chart_opt) |char| : (chart_opt = self.source.next()) {
            switch (status) {
                .text => {
                    if (isValidKeyChar(char)) {
                        try loadBuf(&buf, i, char);
                        i += 1;
                    } else if (isQuoteChar(char)) {
                        try loadBuf(&buf, i, char);
                        i += 1;
                        open_quote = char;
                        status = statuses.quoted_text;
                    } else {
                        break .{ char, Token{ .table_key = try self.allocator.dupe(u8, buf[0..i]) } };
                    }
                },
                .quoted_text => {
                    if (open_quote) |quote| {
                        if (char == quote) {
                            try loadBuf(&buf, i, char);
                            i += 1;
                            open_quote = null;
                            status = statuses.text;
                        } else {
                            try loadBuf(&buf, i, char);
                            i += 1;
                        }
                    } else {
                        unreachable;
                    }
                },
            }
        } else TokenError.invalid_status;
    }
};

fn isQuoteChar(char: u8) bool {
    return char == '\'' or char == '"';
}
fn isValidKeyChar(char: u8) bool {
    return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z') or (char >= '0' and char <= '9') or char == '.';
}

fn loadBuf(buf: []u8, i: usize, char: u8) TokenError!void {
    if (i < buf.len) {
        buf[i] = char;
    } else {
        return TokenError.InvalidBufferAccess;
    }
}

test "tokenizer" {
    const input = [_]struct { []const u8, []const u8 }{
        .{ "testo ", "testo" },
        .{ "testo.ops ", "testo.ops" },
        .{ "\"testo\".ops ", "\"testo\".ops" },
        .{ "'testo'.ops ", "'testo'.ops" },
        .{ "001 ", "001" },
    };
    for (input) |v| {
        const in, const ex = v;
        print("Testing: {s}\n", .{in});
        var strs = StringSource{ .i = 0, .str = in };
        var tokenizer = Tokenizer.init(std.testing.allocator, strs.reader());

        const tok = tokenizer.next() catch |err| {
            print("err: {}\n", .{err});
            unreachable;
        };
        switch (tok.?) {
            .table_key => |key| {
                print("Expect: [{s}], Value: [{s}]\n", .{ ex, key });
                try expect(std.mem.eql(u8, key, ex));
                std.testing.allocator.free(key);
            },
            else => unreachable,
        }
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

test "testing my automa" {
    const input = "property.\"value ops\".lol =";
    var atm = automa.KeyAtm.init(std.testing.allocator);
    var tokens: ?[]automa.Token = null;
    var status = automa.Status.s1;
    for (input) |c| {
        if (try atm.move(status, c)) |move| {
            status, tokens = move;
        } else unreachable;
    }
    if (tokens) |t| {
        const key = switch(t[0]) {
            .table_key => |key| key,
            else => unreachable,
        };
        switch(t[1]) {
            .assign => {},
            else => unreachable,
        }
        try std.testing.expect(std.mem.eql(u8, "property.\"value ops\".lol", key));
        std.testing.allocator.free(key);
        std.testing.allocator.free(t);
    } else unreachable;
}
