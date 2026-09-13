const std = @import("std");
const zstring = @import("zstring");

// ============================================================================
// charAt() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.charat
// ============================================================================

test "spec - charAt basic functionality" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".charAt(0) === "h"
    const ch0 = try str.charAt(allocator, 0);
    defer allocator.free(ch0);
    try std.testing.expectEqualStrings("h", ch0);

    // "hello".charAt(1) === "e"
    const ch1 = try str.charAt(allocator, 1);
    defer allocator.free(ch1);
    try std.testing.expectEqualStrings("e", ch1);

    // "hello".charAt(4) === "o"
    const ch4 = try str.charAt(allocator, 4);
    defer allocator.free(ch4);
    try std.testing.expectEqualStrings("o", ch4);
}

test "spec - charAt out of bounds returns empty string" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".charAt(5) === ""
    const ch5 = try str.charAt(allocator, 5);
    defer allocator.free(ch5);
    try std.testing.expectEqualStrings("", ch5);

    // "hello".charAt(100) === ""
    const ch100 = try str.charAt(allocator, 100);
    defer allocator.free(ch100);
    try std.testing.expectEqualStrings("", ch100);

    // "hello".charAt(-1) === "" (negative indices are out of bounds)
    const ch_neg = try str.charAt(allocator, -1);
    defer allocator.free(ch_neg);
    try std.testing.expectEqualStrings("", ch_neg);
}

test "spec - charAt with surrogate pairs" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("😀A");

    // In JavaScript:
    // "😀A".length === 3 (2 for emoji + 1 for 'A')
    // "😀A".charAt(0) === "\uD83D" (high surrogate)
    // "😀A".charAt(1) === "\uDE00" (low surrogate)
    // "😀A".charAt(2) === "A"
    //
    // Matches real Node now: each lone surrogate half is WTF-8-encoded
    // (see encodeSurrogateWtf8), not the whole 4-byte emoji
    // (z-string-surrogate-charat.md).
    const ch0 = try str.charAt(allocator, 0);
    defer allocator.free(ch0);
    try std.testing.expectEqualStrings("\xED\xA0\xBD", ch0);

    const ch1 = try str.charAt(allocator, 1);
    defer allocator.free(ch1);
    try std.testing.expectEqualStrings("\xED\xB8\x80", ch1);

    const ch2 = try str.charAt(allocator, 2);
    defer allocator.free(ch2);
    try std.testing.expectEqualStrings("A", ch2);
}

test "spec - charAt empty string" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("");

    // "".charAt(0) === ""
    const ch = try str.charAt(allocator, 0);
    defer allocator.free(ch);
    try std.testing.expectEqualStrings("", ch);
}

// ============================================================================
// at() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.at
// ============================================================================

test "spec - at basic functionality" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".at(0) === "h"
    const ch0 = try str.at(allocator, 0);
    try std.testing.expect(ch0 != null);
    defer allocator.free(ch0.?);
    try std.testing.expectEqualStrings("h", ch0.?);

    // "hello".at(4) === "o"
    const ch4 = try str.at(allocator, 4);
    try std.testing.expect(ch4 != null);
    defer allocator.free(ch4.?);
    try std.testing.expectEqualStrings("o", ch4.?);
}

test "spec - at negative indices" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".at(-1) === "o"
    const ch_neg1 = try str.at(allocator, -1);
    try std.testing.expect(ch_neg1 != null);
    defer allocator.free(ch_neg1.?);
    try std.testing.expectEqualStrings("o", ch_neg1.?);

    // "hello".at(-2) === "l"
    const ch_neg2 = try str.at(allocator, -2);
    try std.testing.expect(ch_neg2 != null);
    defer allocator.free(ch_neg2.?);
    try std.testing.expectEqualStrings("l", ch_neg2.?);

    // "hello".at(-5) === "h"
    const ch_neg5 = try str.at(allocator, -5);
    try std.testing.expect(ch_neg5 != null);
    defer allocator.free(ch_neg5.?);
    try std.testing.expectEqualStrings("h", ch_neg5.?);
}

test "spec - at out of bounds returns undefined (null)" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // "hello".at(5) === undefined
    const ch5 = try str.at(allocator, 5);
    try std.testing.expect(ch5 == null);

    // "hello".at(100) === undefined
    const ch100 = try str.at(allocator, 100);
    try std.testing.expect(ch100 == null);

    // "hello".at(-6) === undefined
    const ch_neg6 = try str.at(allocator, -6);
    try std.testing.expect(ch_neg6 == null);

    // "hello".at(-100) === undefined
    const ch_neg100 = try str.at(allocator, -100);
    try std.testing.expect(ch_neg100 == null);
}

test "spec - at with emoji and negative index" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("😀😃");

    // "😀😃".length === 4 in JS (2 code units each): at(-1) is the
    // LAST code unit -- 😃's own low-surrogate half (U+DE03), not the
    // whole second emoji, confirmed against real Node
    // (z-string-surrogate-charat.md).
    const ch = try str.at(allocator, -1);
    try std.testing.expect(ch != null);
    defer allocator.free(ch.?);
    try std.testing.expectEqualStrings("\xED\xB8\x83", ch.?);
}

// ============================================================================
// charCodeAt() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.charcodeat
// ============================================================================

test "spec - charCodeAt basic functionality" {
    const str = zstring.ZString.init("ABC");

    // "ABC".charCodeAt(0) === 65
    try std.testing.expectEqual(@as(?u16, 65), str.charCodeAt(0));

    // "ABC".charCodeAt(1) === 66
    try std.testing.expectEqual(@as(?u16, 66), str.charCodeAt(1));

    // "ABC".charCodeAt(2) === 67
    try std.testing.expectEqual(@as(?u16, 67), str.charCodeAt(2));
}

test "spec - charCodeAt out of bounds returns NaN (null)" {
    const str = zstring.ZString.init("hello");

    // "hello".charCodeAt(5) === NaN
    try std.testing.expectEqual(@as(?u16, null), str.charCodeAt(5));

    // "hello".charCodeAt(-1) === NaN
    try std.testing.expectEqual(@as(?u16, null), str.charCodeAt(-1));

    // "hello".charCodeAt(100) === NaN
    try std.testing.expectEqual(@as(?u16, null), str.charCodeAt(100));
}

test "spec - charCodeAt with surrogate pairs" {
    const str = zstring.ZString.init("😀");

    // In JavaScript:
    // "😀".charCodeAt(0) === 0xD83D (55357) - high surrogate
    // "😀".charCodeAt(1) === 0xDE00 (56832) - low surrogate

    try std.testing.expectEqual(@as(?u16, 0xD83D), str.charCodeAt(0));
    try std.testing.expectEqual(@as(?u16, 0xDE00), str.charCodeAt(1));

    // "😀".charCodeAt(2) === NaN (out of bounds)
    try std.testing.expectEqual(@as(?u16, null), str.charCodeAt(2));
}

test "spec - charCodeAt with Unicode BMP characters" {
    // Test various Unicode characters in the Basic Multilingual Plane

    // "©" (copyright sign, U+00A9)
    const str1 = zstring.ZString.init("©");
    try std.testing.expectEqual(@as(?u16, 0x00A9), str1.charCodeAt(0));

    // "€" (euro sign, U+20AC)
    const str2 = zstring.ZString.init("€");
    try std.testing.expectEqual(@as(?u16, 0x20AC), str2.charCodeAt(0));

    // "你" (Chinese character, U+4F60)
    const str3 = zstring.ZString.init("你");
    try std.testing.expectEqual(@as(?u16, 0x4F60), str3.charCodeAt(0));
}

// ============================================================================
// codePointAt() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.codepointat
// ============================================================================

test "spec - codePointAt basic functionality" {
    const str = zstring.ZString.init("ABC");

    // "ABC".codePointAt(0) === 65
    try std.testing.expectEqual(@as(?u21, 65), str.codePointAt(0));

    // "ABC".codePointAt(1) === 66
    try std.testing.expectEqual(@as(?u21, 66), str.codePointAt(1));

    // "ABC".codePointAt(2) === 67
    try std.testing.expectEqual(@as(?u21, 67), str.codePointAt(2));
}

test "spec - codePointAt out of bounds returns undefined (null)" {
    const str = zstring.ZString.init("hello");

    // "hello".codePointAt(5) === undefined
    try std.testing.expectEqual(@as(?u21, null), str.codePointAt(5));

    // "hello".codePointAt(-1) === undefined
    try std.testing.expectEqual(@as(?u21, null), str.codePointAt(-1));
}

test "spec - codePointAt with surrogate pairs" {
    const str = zstring.ZString.init("😀");

    // In JavaScript:
    // "😀".codePointAt(0) === 0x1F600 (128512) - full code point
    // "😀".codePointAt(1) === 0xDE00 (56832) - low surrogate only

    // At high surrogate position, return full code point
    try std.testing.expectEqual(@as(?u21, 0x1F600), str.codePointAt(0));

    // At low surrogate position, return just that surrogate's own
    // value -- confirmed against real Node, no re-combination
    // (z-string-surrogate-charat.md).
    try std.testing.expectEqual(@as(?u21, 0xDE00), str.codePointAt(1));
}

test "spec - codePointAt with mixed content" {
    const str = zstring.ZString.init("A😀B");

    // "A😀B".length === 4 in JS (A=1, emoji=2, B=1)
    // "A😀B".codePointAt(0) === 65 ('A')
    try std.testing.expectEqual(@as(?u21, 0x0041), str.codePointAt(0));

    // "A😀B".codePointAt(1) === 0x1F600 (pair-start position, combined)
    try std.testing.expectEqual(@as(?u21, 0x1F600), str.codePointAt(1));

    // "A😀B".codePointAt(2) === 0xDE00 (low-surrogate position, own value)
    try std.testing.expectEqual(@as(?u21, 0xDE00), str.codePointAt(2));

    // "A😀B".codePointAt(3) === 66 ('B')
    try std.testing.expectEqual(@as(?u21, 0x0042), str.codePointAt(3));
}

test "spec - codePointAt vs charCodeAt difference" {
    const str = zstring.ZString.init("😀");

    // charCodeAt returns surrogate code units
    const charCode = str.charCodeAt(0);
    try std.testing.expectEqual(@as(?u16, 0xD83D), charCode);

    // codePointAt returns the full Unicode code point
    const codePoint = str.codePointAt(0);
    try std.testing.expectEqual(@as(?u21, 0x1F600), codePoint);

    // They're different!
    try std.testing.expect(charCode.? != codePoint.?);
}

// ============================================================================
// Cross-method compatibility tests
// ============================================================================

test "spec - charAt and charCodeAt consistency" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("A");

    // Get character with charAt
    const ch = try str.charAt(allocator, 0);
    defer allocator.free(ch);

    // Get code with charCodeAt
    const code = str.charCodeAt(0);

    // They should represent the same character
    try std.testing.expectEqualStrings("A", ch);
    try std.testing.expectEqual(@as(?u16, 0x0041), code);
}

test "spec - at and charAt behavior difference" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("hello");

    // charAt with out of bounds returns empty string
    const ch_out = try str.charAt(allocator, 10);
    defer allocator.free(ch_out);
    try std.testing.expectEqualStrings("", ch_out);

    // at with out of bounds returns null
    const at_out = try str.at(allocator, 10);
    try std.testing.expect(at_out == null);

    // charAt doesn't support negative indices
    const ch_neg = try str.charAt(allocator, -1);
    defer allocator.free(ch_neg);
    try std.testing.expectEqualStrings("", ch_neg);

    // at supports negative indices
    const at_neg = try str.at(allocator, -1);
    try std.testing.expect(at_neg != null);
    defer allocator.free(at_neg.?);
    try std.testing.expectEqualStrings("o", at_neg.?);
}
