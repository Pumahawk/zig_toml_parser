const std = @import("std");

const buf = @import("../buffers.zig");

const NflAtm = @import("NumFixLenAtm.zig");

const Status = enum {
    // TODO redefine status
    // s1,
    s2,
    s3,
    s4,
};

const LBuf = buf.BufS(u8, 1024, 1024);

const Ret = ?struct { Status, ?[]const u8 };
const Start = []Status;

const StringAtm = struct {
    const Self = @This();

    state_start: []Status,
    state: ?Status,
    buf: LBuf,

    pub fn move(self: *Self, s: Status, c: u8) !Ret {
        return if (self.state) |state| {
            // TODO define arch in automa
            return switch (state) {
                .s2 => fromS2(s, c),
                .s3 => fromS3(s, c),
                .s4 => fromS4(s, c),
            };
        } else {
            // TODO start status actions
        }
    }

    pub fn reset(self: *Self) void {
        _ = self;
    }

    pub fn initFromStatus(allocator: std.mem.Allocator, start: Start) Self {
        return .{
            .state_start = start,
            .state = null,
            .buf = LBuf.init(allocator),
        };
    }

    pub fn fromS2(self: Self, s: Status, c: u8) !Ret {
        return if (validStrC(s)) {
            try self.buf.load(c);
            return .{.s2, null };
        } else switch (c) {
            '"' => .{ .s4, self.tokenize() },
            '\\' => .{ .s3, null },
            else => error.InvalidStatus;
        };
    }

    pub fn fromS3(self: Self, s: Status, c: u8) !Ret {
        // TODO 
        return error.NotImplementedYet;
    }

    pub fn fromS4(self: Self, s: Status, c: u8) !Ret {
        return error.NotImplementedYet;
    }

    pub fn tokenize() []const u8 {
        // Alloc token
    }
};

fn validStrC(c: u8) bool {
}
