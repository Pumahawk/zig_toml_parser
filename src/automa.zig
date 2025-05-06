const std = @import("std");
const buffers = @import("buffers.zig");

const buf_size: usize = 512;
const BufFU8 = BufU8(buf_size);

pub fn BufU8(bs: usize) type {
    return buffers.Buf(u8, bs);
}

pub fn BufSU8(bss: usize, bs: usize) type {
    return buffers.BufS(u8, bss, bs);
}

pub const Status = enum {
    s1,
    s2,
    s3,
    s4,
    s5,
    s6,
    s7,
    s8,
    s9,
    s10,
    s11,
};

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

pub const AtmMove = ?struct { Status, ?[]Token };

pub const KeyAtm = struct {
    allocator: std.mem.Allocator,

    buf: BufFU8,
    quote: ?u8,

    pub fn init(allocator: std.mem.Allocator) KeyAtm {
        return .{
            .allocator = allocator,
            .buf = BufFU8.init(),
            .quote = null,
        };
    }

    pub fn move(self: *KeyAtm, s: Status, c: u8) !AtmMove {
        switch (s) {
            .s1 => {
                if (c == ' ') {
                    return .{ Status.s1, null };
                } else if (isValidKeyChar(c)) {
                    try self.buf.load(c);
                    return .{ Status.s1, null };
                } else if (isValidKeyQuote(c)) {
                    try self.buf.load(c);
                    self.quote = c;
                    return .{ Status.s2, null };
                } else if (c == '=') {
                    return .{ Status.s3, try self.allocator.dupe(Token, &[_]Token{ try self.popToken(), Token.assign }) };
                } else {
                    return error.InvalidStatus;
                }
            },
            .s2 => {
                if (self.quote) |quote| {
                    if (c == quote) {
                        self.quote = null;
                        try self.buf.load(c);
                        return .{ Status.s1, null };
                    } else {
                        try self.buf.load(c);
                        return .{ Status.s2, null };
                    }
                } else unreachable;
            },
            else => {
                return null;
            },
        }
    }

    fn popToken(self: *KeyAtm) !Token {
        const token = Token{ .table_key = try self.allocator.dupe(u8, self.buf.slice()) };
        self.buf.reset();
        return token;
    }
};

fn isValidKeyQuote(char: u8) bool {
    return char == '\'' or char == '"';
}

fn isValidKeyChar(char: u8) bool {
    return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z') or (char >= '0' and char <= '9') or char == '.';
}

const StringAtm = struct {
    allocator: std.mem.Allocator,

    buf_slice: BufSU8(100, 1024),
    buf_quote: BufU8(2),

    pub fn init(allocator: std.mem.Allocator) StringAtm {
        return .{
            .allocator = allocator,
            .buf_slice = BufSU8(100, 1024).init(allocator),
            .buf_quote = BufU8(2).init(),
        };
    }

    pub fn move(self: *StringAtm, s: Status, c: u8) !AtmMove {
        return switch (s) {
            .s3 => {
                return switch (c) {
                    ' ' => .{ s, null },
                    '"' => .{ .s4, null },
                    else => null,
                };
            },
            .s4 => {
                return if (isValidStringChar(c)) {
                    try self.buf_slice.load(c);
                    return .{ .s6, null };
                } else switch (c) {
                    '"' => .{ .s7, null },
                    else => null,
                };
            },
            .s6 => {
                return if (isValidStringChar(c)) {
                    // TODO add to buffer
                    return .{ .s6, null };
                } else switch (c) {
                    '"' => .{ .s5, try self.allocator.dupe(Token, &[_]Token{try self.generateStringToken()}) },
                    else => null,
                };
            },
            .s7 => {
                return switch (c) {
                    '=' => .{ .s8, null },
                    '\n', ' ' => .{ .s5, null },
                    else => null,
                };
            },
            .s8 => {
                return switch (c) {
                    '"' => .{ .s9, null },
                    else => {
                        // TODO load buf
                        return .{ .s8, null };
                    },
                };
            },
            .s9 => {
                return switch (c) {
                    '"' => .{ .s10, null },
                    else => {
                        // TODO load buf
                        return .{ .s11, null };
                    },
                };
            },
            .s10 => {
                return switch (c) {
                    '"' => {
                        // generate token
                        // const token = Token{.table_value = };
                        // return .{ .s5, [_]Token { token } };
                        return .{ .s5, null };
                    },
                    else => return null,
                };
            },
            .s11 => {
                return switch (c) {
                    ' ' => .{ .s11, null },
                    '"', '\r', '\n' => .{ .s5, null },
                    else => null,
                };
            },
            else => {
                return null;
            },
        };
    }

    pub fn generateStringToken(self: *StringAtm) !Token {
        // TODO generate token
        _ = self;
        return Token{ .table_value = "Test" };
    }
};

pub fn isValidStringChar(c: u8) bool {
    // return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '.';
    return c != '\n' and c != '"';
}

test "testing KeyAtm" {
    const input = "property.\"value ops\".lol =";
    var atm = KeyAtm.init(std.testing.allocator);
    var tokens: ?[]Token = null;
    var status = Status.s1;
    for (input) |c| {
        if (try atm.move(status, c)) |move| {
            status, tokens = move;
        } else unreachable;
    }
    if (tokens) |t| {
        const key = switch (t[0]) {
            .table_key => |key| key,
            else => unreachable,
        };
        switch (t[1]) {
            .assign => {},
            else => unreachable,
        }
        try std.testing.expect(std.mem.eql(u8, "property.\"value ops\".lol", key));
        std.testing.allocator.free(key);
        std.testing.allocator.free(t);
    } else unreachable;
}

test "testing StringAtm" {
    // TODO Add check token testing
    var satm = StringAtm.init(std.testing.allocator);
    const input = "\"this is my simpl string value\"";
    var status = Status.s3;
    var tokens: ?[]Token = null;
    for (input) |c| {
        if (try satm.move(status, c)) |result| {
            status, const tokens_opt = result;
            if (tokens_opt) |_| {
                tokens = tokens_opt;
            }
        } else unreachable;
    }
    if (tokens) |t| {
        std.testing.allocator.free(t);
    } else unreachable;
}
