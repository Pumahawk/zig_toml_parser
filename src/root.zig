const std = @import("std");
const expect = std.testing.expect;

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
    const node = TomplNode {
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

// pub const Source = fn() ?u8;
//
// pub const ParseError = error {
// };
//
// const Status = enum {
//     init,
// };
//
// pub const Parser = struct {
//     allocator: std.mem.Allocator,
//
//     pub fn init(allocator: std.mem.Allocator) Parser {
//         return .{
//             .allocator = allocator,
//         };
//     }
//     pub fn parse(self: Parser, source: Source) !?TomplNode {
//         var status = Status.init;
//         var node = TomplNode {
//             .null_value = null,
//         };
//         while (source()) | c | {
//             switch (status) {
//             }
//         }
//         return node;
//     }
// };
//
// test "parse text" {
//     const input = "\"Hello, World!\"";
//     _ = input;
// }
