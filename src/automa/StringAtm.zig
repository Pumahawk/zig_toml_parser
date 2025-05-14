const std = @import("std");

const buf = @import("../buffers.zig");

const NflAtm = @import("NumFixLenAtm.zig");

const Status = enum {
    // TODO redefine status
    // s1,
    s2,
    s3,
    s4,
    s5,
    s6,
};

const LBuf = buf.BufS(u8, 1024, 1024);
const ShortUCode = NflAtm.NumFixLenAtm(4);
const LongUCode = NflAtm.NumFixLenAtm(8);

pub const Ret = ?struct { Status, ?[]const u8 };
pub const Start = []Status;

pub const StringAtm = struct {
    const Self = @This();

    state_start: []Status,
    buf: LBuf,

    s_uc_atm: ShortUCode,
    l_uc_atm: LongUCode,

    pub fn move(self: *Self, s: Status, c: u8) !Ret {
        return switch (s) {
            .s2 => self.fromS2(c),
            .s3 => self.fromS3(c),
            .s4 => self.fromS4(c),
        };
    }

    pub fn reset(self: *Self) void {
        _ = self;
    }

    pub fn initFromStatus(allocator: std.mem.Allocator, start: Start) Self {
        return .{
            .state_start = start,
            .state = null,
            .buf = LBuf.init(allocator),
            .s_uc_atm = ShortUCode.initFromStatus(NflAtm.Status.s1),
            .l_uc_atm = LongUCode.initFromStatus(NflAtm.Status.s1),
        };
    }

    pub fn fromS2(self: Self, c: u8) !Ret {
        return if (validStrC(c)) {
            try self.buf.load(c);
            return .{ .s2, null };
        } else switch (c) { // Check if buf load needed
            '"' => .{ .s4, self.tokenize() },
            '\\' => .{ .s3, null },
            else => error.InvalidStatus,
        };
    }

    pub fn fromS3(self: Self, s: Status, c: u8) !Ret {
        return if (isEscaperChar(c)) {
            // TODO
        } else {
            try self.buf.load(c);
            switch (c) {
                'U' => .{ .s6, null },
                'u' => .{ .s5, null },
                else => null,
            }
        };
    }

    pub fn fromS4(self: Self, c: u8) !Ret {
        _ = self;
        _ = c;
        return error.NotImplementedYet;
    }

    pub fn tokenize() []const u8 {
        // Alloc token
    }
};

fn validStrC(c: u8) bool {
    _ = c;
    return false;
}

fn isEscaperChar() bool {
    // TODO develop
    return false;
}

test {
    // TODO Create tests
}
