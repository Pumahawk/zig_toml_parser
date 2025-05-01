const std = @import("std");

const buf_size: usize = 512;

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

pub const AtmMove = ? struct { Status, ?[]Token};

pub const KeyAtm = struct {

    allocator: std.mem.Allocator,

    buf: [buf_size]u8,
    i: usize,
    quote: ?u8,

    pub fn init(allocator: std.mem.Allocator) KeyAtm {
        return .{
            .allocator = allocator,
            .buf = undefined,
            .i = 0,
            .quote = null,
        };
    }

    pub fn move(self: *KeyAtm, s: Status, c: u8) !AtmMove {
        switch (s) {
            .s1 => {
                if (c == ' ') {
                    return . { Status.s1, null };
                } else if (isValidKeyChar(c)) {
                    try self.loadBuf(c);
                    return . { Status.s1, null };
                } else if (isValidKeyQuote(c)) {
                    try self.loadBuf(c);
                    self.quote = c;
                    return . { Status.s2, null };
                } else if (c == '=') {
                    return . { Status.s3, try self.allocator.dupe(Token, &[_]Token {try self.popToken(), Token.assign })};
                } else {
                    return error.InvalidStatus;
                }
            },
            .s2 => {
                if (self.quote) |quote| {
                    if (c == quote) {
                        self.quote = null;
                        try self.loadBuf(c);
                        return . { Status.s1, null };
                    } else {
                        try self.loadBuf(c);
                        return . { Status.s2, null };
                    }
                } else unreachable;
            },
            else => {
                return null;
            },
        }
    }

    fn loadBuf(self: *KeyAtm, c: u8) !void {
        if (self.i < self.buf.len) {
            self.buf[self.i] = c;
            self.i += 1;
        } else {
            return error.FullBuffer;
        }
    }

    fn popToken(self: *KeyAtm) !Token {
        const token = Token { .table_key = try self.allocator.dupe(u8, self.buf[0..self.i]) };
        self.i = 0;
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

    buf: [buf_size]u8,
    i_buf: usize,
    buf_slice: [buf_size]u8,
    i_buf_slice: usize,
    buf_quote: [2]u8,
    i_buf_quote: usize,

    pub fn init(allocator: std.mem.Allocator) StringAtm {
        return .{
            .allocator = allocator,
            .buf = undefined,
            .i_buf = 0,
            .buf_slice = undefined,
            .i_buf_slice = 0,
            .buf_quote = undefined,
            .i_buf_quote = 0,
        };
    }

    pub fn move(self: *StringAtm, s: Status, c: u8) !AtmMove {
        _ = self; // TODO remove
        switch (s) {
            .c3 => {
                return switch (c) {
                    ' ' => |cs| .{ cs, null },
                    '"' => .{ .s4, null },
                    else => null,
                };
            },
            .c4 => {
                return if (isValidStringChar(c)) {
                    // TODO add to buffer
                    return .{ .c6, null };
                } else switch (c) {
                    '"' => .{ .c7, null },
                    else => null,
                };
            },
            .c5 => {
            },
            .c6 => {
            },
            .c7 => {
            },
            .c8 => {
            },
            .c9 => {
            },
            .c10 => {
            },
            .c11 => {
            },
            else => {
                return null;
            },
        }
    }
};
pub fn isValidStringChar(c: u8) bool {
    _ = c; // TODO remove
    return false;
}
test "testing my automa" {
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
