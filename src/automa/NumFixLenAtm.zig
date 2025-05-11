const std = @import("std");
const testing = std.testing;
const buf = @import("../buffers.zig");
const atm = @import("./automa.zig");

pub const NumFixLenAtmRet = ?struct { atm.Status, ?[]const u8 };

pub const NumFixLenAtmStart = []atm.Status;
pub const NumFixLenAtmEnd = atm.Status;
pub const NumFixLenAtmMid = atm.Status;

pub fn NumFixLenAtm(size: usize) type {
    return struct {
        const Self = @This();

        state_start: []atm.Status,
        state_mid: atm.Status,
        state_end: atm.Status,

        count_i: usize,
        buf: buf.Buf(u8, size),

        pub fn move(self: *Self, s: atm.Status, c: u8) !NumFixLenAtmRet {
            return if (self.count_i > 0) {
                return if (c >= '0' and c <= '9') {
                    try self.load(c);
                    return if (self.count_i < size) {
                        return .{ self.state_mid, null };
                    } else {
                        const ret = .{ self.state_end, self.buf.slice() };
                        defer self.reset();
                        return ret;
                    };
                } else error.InvalidStatus;
            } else {
                return for (self.state_start) |state| {
                    if (s == state) {
                        if (c >= '0' and c <= '9') {
                                try self.load(c);
                                return .{ self.state_mid, null };
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

        pub fn init(start: NumFixLenAtmStart, mid: NumFixLenAtmMid, end: NumFixLenAtmEnd) Self {
            return .{
                .state_start = start,
                .state_end = end,
                .state_mid = mid,

                .count_i = 0,
                .buf = buf.Buf(u8, size).init(),
            };
        }
    };
}

test "NumFixLenAtm" {
    const s1 = atm.Status.s1;
    const s2 = atm.Status.s2;
    const s3 = atm.Status.s3;
    var startS = [_]atm.Status{s1};
    var nfla = NumFixLenAtm(3).init(&startS, s2, s3);
    const input = "123";
    var snow = atm.Status.s1;
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
