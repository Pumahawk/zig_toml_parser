const std = @import("std");

pub fn Buf(T: type, size: usize) type {
    return struct {
        const Self = @This();
        i: usize,
        buf: [size]T,

        pub fn init() Buf(T, size) {
            return .{
                .i = 0,
                .buf = undefined,
            };
        }

        pub fn reset(self: *Self) void {
            self.i = 0;
        }

        pub fn load(self: *Self, c: T) !void {
            if (self.i < self.buf.len) {
                self.buf[self.i] = c;
                self.i += 1;
            } else {
                return error.FullBuffer;
            }
        }

        pub fn slice(self: *Self) []T {
            return self.buf[0..self.i];
        }
    };
}

pub fn BufS(T: type, size_s: usize, size_b: usize) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        buf: Buf(T, size_b),
        buf_s: Buf([]T, size_s),

        pub fn init(allocator: std.mem.Allocator) BufS(T, size_s, size_b) {
            return .{
                .allocator = allocator,
                .buf = Buf(T, size_b).init(),
                .buf_s = Buf([]T, size_s).init(),
            };
        }

        pub fn load(self: *Self, v: T) !void {
            self.buf.load(v) catch |err| {
                switch (err) {
                    error.FullBuffer => {
                        const buf_tmp = try self.allocator.dupe(T, self.buf.slice());
                        self.buf.reset();
                        try self.buf_s.load(buf_tmp);
                    },
                }
            };
        }
    };
}
