const std = @import("std");
const testing = std.testing;
const buf = @import("../buffers.zig");

pub const Status = enum {
    s1,
    s2,
    s3,
};

pub const Ret = ?struct { Status, ?[]const u8 };

pub const Start = []Status;
pub const End = Status;

pub fn NumFixLenAtm(size: usize) type {
    return struct {
        const Self = @This();

        state_start: []Status,

        count_i: usize,
        buf: buf.Buf(u8, size),

        pub fn move(self: *Self, s: Status, c: u8) !Ret {
            return if (self.count_i > 0) {
                return if (c >= '0' and c <= '9') {
                    try self.load(c);
                    return if (self.count_i < size) {
                        return .{ Status.s2, null };
                    } else {
                        const ret = .{ Status.s3, self.buf.slice() };
                        self.reset();
                        return ret;
                    };
                } else error.InvalidStatus;
            } else {
                return for (self.state_start) |state| {
                    if (s == state) {
                        if (c >= '0' and c <= '9') {
                            try self.load(c);
                            return .{ Status.s2, null };
                        }
                    }
                } else null;
            };
        }

        fn reset(self: *Self) void {
            self.count_i = 0;
            self.buf.reset();
        }

        fn load(self: *Self, c: u8) !void {
            self.count_i += 1;
            try self.buf.load(c);
        }

        pub fn initFromStatus(start: Start) Self {
            return .{
                .state_start = start,

                .count_i = 0,
                .buf = buf.Buf(u8, size).init(),
            };
        }
    };
}

test "NumFixLenAtm" {
    const s1 = Status.s1;
    const s2 = Status.s2;
    const s3 = Status.s3;
    var startS = [_]Status{s1};
    var nfla = NumFixLenAtm(3).initFromStatus(&startS);
    const input = "123";
    var snow = Status.s1;
    if (try nfla.move(s1, input[0])) |moved| {
        snow, const tok = moved;
        try testing.expectEqual(s2, snow);
        try testing.expect(tok == null);
    } else unreachable;
    if (try nfla.move(snow, input[1])) |moved| {
        snow, const tok = moved;
        try testing.expectEqual(s2, snow);
        try testing.expect(tok == null);
    } else unreachable;
    if (try nfla.move(snow, input[2])) |moved| {
        snow, const tok = moved;
        try testing.expectEqual(s3, snow);
        if (tok) |slice| {
            try testing.expectEqualSlices(u8, input, slice);
        } else unreachable;
    } else unreachable;
}
