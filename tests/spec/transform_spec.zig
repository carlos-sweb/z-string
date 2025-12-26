const std = @import("std");
const zstring = @import("zstring");

// ============================================================================
// slice() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.slice
// ============================================================================

test "spec - slice basic functionality" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello world");

    // "hello world".slice(0, 5) === "hello"
    const result1 = try str.slice(allocator, 0, 5);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello", result1);

    // "hello world".slice(6, 11) === "world"
    const result2 = try str.slice(allocator, 6, 11);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("world", result2);

    // "hello world".slice(6) === "world" (to end)
    const result3 = try str.slice(allocator, 6, null);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("world", result3);
}

test "spec - slice with negative indices" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello world");

    // "hello world".slice(-5) === "world"
    const result1 = try str.slice(allocator, -5, null);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("world", result1);

    // "hello world".slice(0, -6) === "hello"
    const result2 = try str.slice(allocator, 0, -6);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello", result2);

    // "hello world".slice(-5, -1) === "worl"
    const result3 = try str.slice(allocator, -5, -1);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("worl", result3);
}

test "spec - slice with start >= end returns empty string" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".slice(3, 1) === ""
    const result1 = try str.slice(allocator, 3, 1);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("", result1);

    // "hello".slice(5, 5) === ""
    const result2 = try str.slice(allocator, 5, 5);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("", result2);
}

test "spec - slice with out of bounds indices" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".slice(10, 20) === ""
    const result1 = try str.slice(allocator, 10, 20);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("", result1);

    // "hello".slice(-10, 3) === "hel"
    const result2 = try str.slice(allocator, -10, 3);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hel", result2);
}

test "spec - slice with emoji (UTF-16 indices)" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("😀😃😄");

    // Each emoji is 2 UTF-16 code units
    // "😀😃😄".slice(0, 2) === "😀"
    const result1 = try str.slice(allocator, 0, 2);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("😀", result1);

    // "😀😃😄".slice(2, 4) === "😃"
    const result2 = try str.slice(allocator, 2, 4);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("😃", result2);

    // "😀😃😄".slice(-2) === "😄"
    const result3 = try str.slice(allocator, -2, null);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("😄", result3);
}

// ============================================================================
// substring() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.substring
// ============================================================================

test "spec - substring basic functionality" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello world");

    // "hello world".substring(0, 5) === "hello"
    const result1 = try str.substring(allocator, 0, 5);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello", result1);

    // "hello world".substring(6, 11) === "world"
    const result2 = try str.substring(allocator, 6, 11);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("world", result2);

    // "hello world".substring(6) === "world"
    const result3 = try str.substring(allocator, 6, null);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("world", result3);
}

test "spec - substring with negative indices treated as 0" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".substring(-2) === "hello" (negative = 0)
    const result1 = try str.substring(allocator, -2, null);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello", result1);

    // "hello".substring(-5, 3) === "hel" (start = 0)
    const result2 = try str.substring(allocator, -5, 3);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hel", result2);

    // "hello".substring(2, -1) === "he" (end = 0, swaps to 0, 2)
    const result3 = try str.substring(allocator, 2, -1);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("he", result3);
}

test "spec - substring swaps indices if start > end" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".substring(3, 1) === "el" (swapped to 1, 3)
    const result1 = try str.substring(allocator, 3, 1);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("el", result1);

    // "hello".substring(5, 2) === "llo" (swapped to 2, 5)
    const result2 = try str.substring(allocator, 5, 2);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("llo", result2);
}

test "spec - substring vs slice key differences" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // Negative index difference
    {
        // slice(-2) -> "lo"
        const slice_result = try str.slice(allocator, -2, null);
        defer allocator.free(slice_result);
        try std.testing.expectEqualStrings("lo", slice_result);

        // substring(-2) -> "hello" (negative becomes 0)
        const substring_result = try str.substring(allocator, -2, null);
        defer allocator.free(substring_result);
        try std.testing.expectEqualStrings("hello", substring_result);
    }

    // Swap behavior difference
    {
        // slice(3, 1) -> ""
        const slice_result = try str.slice(allocator, 3, 1);
        defer allocator.free(slice_result);
        try std.testing.expectEqualStrings("", slice_result);

        // substring(3, 1) -> "el" (swaps to 1, 3)
        const substring_result = try str.substring(allocator, 3, 1);
        defer allocator.free(substring_result);
        try std.testing.expectEqualStrings("el", substring_result);
    }
}

// ============================================================================
// concat() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.concat
// ============================================================================

test "spec - concat basic functionality" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".concat(" ", "world") === "hello world"
    const result1 = try str.concat(allocator, &[_][]const u8{ " ", "world" });
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello world", result1);

    // "hello".concat("!") === "hello!"
    const result2 = try str.concat(allocator, &[_][]const u8{"!"});
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello!", result2);
}

test "spec - concat multiple strings" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("a");

    // "a".concat("b", "c", "d") === "abcd"
    const result = try str.concat(allocator, &[_][]const u8{ "b", "c", "d" });
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abcd", result);
}

test "spec - concat with empty strings" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".concat("") === "hello"
    const result1 = try str.concat(allocator, &[_][]const u8{""});
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello", result1);

    // "hello".concat() === "hello" (no arguments)
    const result2 = try str.concat(allocator, &[_][]const u8{});
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello", result2);

    // "".concat("hello") === "hello"
    const empty_str = zstring.ZString.init("");
    const result3 = try empty_str.concat(allocator, &[_][]const u8{"hello"});
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("hello", result3);
}

test "spec - concat with emoji" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".concat("😀", "world") === "hello😀world"
    const result = try str.concat(allocator, &[_][]const u8{ "😀", "world" });
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello😀world", result);
}

test "spec - concat does not modify original" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    const result = try str.concat(allocator, &[_][]const u8{"world"});
    defer allocator.free(result);

    // Original unchanged
    try std.testing.expectEqualStrings("hello", str.data);
    // Result is concatenated
    try std.testing.expectEqualStrings("helloworld", result);
}

// ============================================================================
// repeat() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.repeat
// ============================================================================

test "spec - repeat basic functionality" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("abc");

    // "abc".repeat(0) === ""
    const result1 = try str.repeat(allocator, 0);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("", result1);

    // "abc".repeat(1) === "abc"
    const result2 = try str.repeat(allocator, 1);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("abc", result2);

    // "abc".repeat(2) === "abcabc"
    const result3 = try str.repeat(allocator, 2);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("abcabc", result3);

    // "abc".repeat(3) === "abcabcabc"
    const result4 = try str.repeat(allocator, 3);
    defer allocator.free(result4);
    try std.testing.expectEqualStrings("abcabcabc", result4);
}

test "spec - repeat with single character" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("-");

    // "-".repeat(10) === "----------"
    const result = try str.repeat(allocator, 10);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("----------", result);
}

test "spec - repeat with emoji" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("😀");

    // "😀".repeat(3) === "😀😀😀"
    const result = try str.repeat(allocator, 3);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("😀😀😀", result);
}

test "spec - repeat with empty string" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("");

    // "".repeat(5) === ""
    const result = try str.repeat(allocator, 5);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "spec - repeat with count 0" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".repeat(0) === ""
    const result = try str.repeat(allocator, 0);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "spec - repeat with negative count throws error" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("abc");

    // "abc".repeat(-1) -> RangeError in JS, error in Zig
    const result = str.repeat(allocator, -1);
    try std.testing.expectError(error.InvalidCount, result);
}

test "spec - repeat does not modify original" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("abc");

    const result = try str.repeat(allocator, 3);
    defer allocator.free(result);

    // Original unchanged
    try std.testing.expectEqualStrings("abc", str.data);
    // Result is repeated
    try std.testing.expectEqualStrings("abcabcabc", result);
}

// ============================================================================
// Cross-method compatibility tests
// ============================================================================

test "spec - slice and concat combination" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello world");

    // Get first word with slice
    const first = try str.slice(allocator, 0, 5);
    defer allocator.free(first);

    // Get second word with slice
    const second = try str.slice(allocator, 6, 11);
    defer allocator.free(second);

    // Concat them with separator
    const first_str = zstring.ZString.init(first);
    const combined = try first_str.concat(allocator, &[_][]const u8{ " + ", second });
    defer allocator.free(combined);

    try std.testing.expectEqualStrings("hello + world", combined);
}

test "spec - repeat and concat combination" {
    const allocator = std.testing.allocator;
    const dash = zstring.ZString.init("-");

    // Create separator
    const sep = try dash.repeat(allocator, 10);
    defer allocator.free(sep);

    // Concat with text
    const sep_str = zstring.ZString.init(sep);
    const result = try sep_str.concat(allocator, &[_][]const u8{ " TITLE ", sep });
    defer allocator.free(result);

    try std.testing.expectEqualStrings("---------- TITLE ----------", result);
}

test "spec - substring and slice produce same result for positive indices" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello world");

    // When both use positive indices and start < end, they're identical
    const slice_result = try str.slice(allocator, 6, 11);
    defer allocator.free(slice_result);

    const substring_result = try str.substring(allocator, 6, 11);
    defer allocator.free(substring_result);

    try std.testing.expectEqualStrings(slice_result, substring_result);
    try std.testing.expectEqualStrings("world", slice_result);
}
