const std = @import("std");
const expect = std.testing.expect;

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
                        try self.buf.load(v);
                        try self.buf_s.load(buf_tmp);
                    },
                }
            };
        }

        fn deinitBuffSlice(self: *Self) void {
            const s = self.buf_s.slice();
            for (s) |arr| {
                self.allocator.free(arr);
            }
        }

        pub fn deinit(self: *Self) void {
            self.deinitBuffSlice();
        }

        pub fn reset(self: *Self) void {
            self.deinitBuffSlice();
            self.buf_s.reset();
            self.buf.reset();
        }

        pub fn allocSlice(self: *Self) ![]T {
            const size_total = self.buf.slice().len + size_b * self.buf_s.slice().len;
            var slice = try self.allocator.alloc(T, size_total);
            var i: usize = 0;
            for (self.buf_s.slice()) |arr| {
                for (arr) |c| {
                    slice[i] = c;
                    i += 1;
                }
            }
            for (self.buf.slice()) |c| {
                slice[i] = c;
                i += 1;
            }
            return slice;
        }
    };
}

test "Buf init, reset and load" {
    const Bufi32 = Buf(i32, 2);
    var bf = Bufi32.init();
    try bf.load(1);
    try bf.load(2);

    const s1 = bf.slice();

    try expect(s1.len == 2);
    try expect(s1[0] == 1);
    try expect(s1[1] == 2);

    bf.reset();

    try bf.load(3);

    const s2 = bf.slice();

    try expect(s2.len == 1);
    try expect(s2[0] == 3);
}

test "Bufs init, reset and load" {
    const Bufsu8 = BufS(u8, 1, 2);
    var bf = Bufsu8.init(std.testing.allocator);
    const s1 = "abcd";
    for (s1) |c| {
        try bf.load(c);
    }
    const value = try bf.allocSlice();
    try std.testing.expectEqualDeep("abcd", value);
    bf.deinit();
    std.testing.allocator.free(value);
}
