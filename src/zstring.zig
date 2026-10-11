// z-string - ECMAScript String API for Zig
//
// This library provides a JavaScript-compatible String implementation in Zig,
// designed to be used as part of an ECMAScript runtime engine.
//
// Key features:
// - UTF-16 code unit based indexing (matching JavaScript behavior)
// - Typed ECMA-262 String operations; see the compatibility matrix for limits
// - UTF-8 internal representation for memory efficiency
// - Explicit memory management with Zig allocators

const std = @import("std");

// Core exports
pub const ZString = @import("core/string.zig").ZString;
pub const unicode_version = @import("unicode/data.zig").version;
pub const Iterator = @import("core/units.zig").Iterator;
pub const utf16 = @import("core/utf16.zig");

// Method modules
pub const access = @import("methods/access.zig");
pub const search = @import("methods/search.zig");
pub const transform = @import("methods/transform.zig");
pub const padding = @import("methods/padding.zig");
pub const trimming = @import("methods/trimming.zig");
pub const split = @import("methods/split.zig");
pub const case = @import("methods/case.zig");
pub const utility = @import("methods/utility.zig");
pub const regex = @import("methods/regex.zig");
pub const compiled_regex = @import("methods/compiled_regex.zig");
pub const CompiledRegex = compiled_regex.CompiledRegex;
pub const DetailedMatch = compiled_regex.DetailedMatch;
pub const PreparedSubject = compiled_regex.PreparedSubject;

// Re-export common types
pub const Allocator = std.mem.Allocator;
pub const Utf16Error = utf16.Utf16Error;

// Error types
pub const ZStringError = error{
    InvalidUtf8,
    InvalidUtf16,
    IndexOutOfBounds,
    InvalidCodePoint,
    AllocationFailed,
    NotImplemented,
};

// Version info
pub const version = .{
    .major = 0,
    .minor = 4,
    .patch = 1,
};

// Tests - this runs all tests from submodules
test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(ZString);
    std.testing.refAllDecls(utf16);
    std.testing.refAllDecls(access);
    std.testing.refAllDecls(search);
    std.testing.refAllDecls(transform);
    std.testing.refAllDecls(padding);
    std.testing.refAllDecls(trimming);
    std.testing.refAllDecls(split);
    std.testing.refAllDecls(case);
    std.testing.refAllDecls(utility);
}

// Basic integration test
test "zstring - basic usage" {
    const allocator = std.testing.allocator;

    // Borrowed string
    var borrowed = ZString.init("hello");
    try std.testing.expectEqual(@as(usize, 5), borrowed.length());

    // Owned string
    var owned = try ZString.initOwned(allocator, "world");
    defer owned.deinit();
    try std.testing.expectEqual(@as(usize, 5), owned.length());

    // Emoji
    var emoji = ZString.init("😀");
    try std.testing.expectEqual(@as(usize, 2), emoji.length()); // 2 UTF-16 code units
}

test "zstring - UTF-16 indexing" {
    const str = "a😀b";
    const byte_idx_emoji = try utf16.utf16IndexToByte(str, 1);
    try std.testing.expectEqual(@as(usize, 1), byte_idx_emoji);

    const utf16_len = utf16.lengthUtf16(str);
    try std.testing.expectEqual(@as(usize, 4), utf16_len); // a=1, emoji=2, b=1
}
