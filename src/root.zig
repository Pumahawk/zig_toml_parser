const std = @import("std");
const expect = std.testing.expect;
const automa = @import("automa/automa.zig");
const bf = @import("buffers.zig");
const NumFixLenAtm = @import("automa/NumFixLenAtm.zig");
const StringAtm = @import("automa//StringAtm.zig");

test "testing" {
    _ = automa;
    _ = bf;
    _ = NumFixLenAtm;
    _ = StringAtm;
}
