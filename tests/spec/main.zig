const std = @import("std");
const zstring = @import("zstring");

// Import all spec test files
test {
    std.testing.refAllDecls(@This());
    _ = @import("access_spec.zig");
    _ = @import("search_spec.zig");
    _ = @import("transform_spec.zig");
    _ = @import("padding_trimming_spec.zig");
    _ = @import("split_spec.zig");
    _ = @import("case_utility_spec.zig");
    _ = @import("regex_spec.zig");
    _ = @import("ecmascript_compliance.zig");
    _ = @import("improvements_spec.zig");
    _ = @import("api_compatibility.zig");
    _ = @import("differential.zig");
    _ = @import("unicode_conformance.zig");
}

test "spec - String.length property" {
    // https://tc39.es/ecma262/#sec-string.prototype.length
    //
    // The length property returns the number of UTF-16 code units

    var str1 = zstring.ZString.init("hello");
    try std.testing.expectEqual(@as(usize, 5), str1.length());

    var str2 = zstring.ZString.init("");
    try std.testing.expectEqual(@as(usize, 0), str2.length());

    var str3 = zstring.ZString.init("😀");
    try std.testing.expectEqual(@as(usize, 2), str3.length()); // Surrogate pair

    var str4 = zstring.ZString.init("café");
    try std.testing.expectEqual(@as(usize, 4), str4.length());
}

test "spec - Empty string behavior" {
    var empty = zstring.ZString.init("");
    try std.testing.expectEqual(@as(usize, 0), empty.length());
    try std.testing.expect(empty.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), empty.byteLength());
}

test "spec - Surrogate pair handling" {
    // JavaScript behavior:
    // "😀".length === 2
    // "😀".charCodeAt(0) === 0xD83D (high surrogate)
    // "😀".charCodeAt(1) === 0xDE00 (low surrogate)

    const emoji = "😀";
    var zstr = zstring.ZString.init(emoji);

    try std.testing.expectEqual(@as(usize, 2), zstr.length());

    const high = try zstring.utf16.codeUnitAt(emoji, 0);
    const low = try zstring.utf16.codeUnitAt(emoji, 1);

    try std.testing.expectEqual(@as(u16, 0xD83D), high);
    try std.testing.expectEqual(@as(u16, 0xDE00), low);
}
