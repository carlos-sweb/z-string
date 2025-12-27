const std = @import("std");
const zstring = @import("zstring");

// ============================================================================
// ECMAScript 262 Compliance Tests
// ============================================================================
//
// These tests verify exact JavaScript behavior as specified in ECMAScript 262.
// Each test includes the JavaScript equivalent and expected behavior.

// ============================================================================
// Character Access - ECMAScript Compliance
// ============================================================================

test "ECMAScript compliance - charAt with out of bounds" {
    // JavaScript: "hello".charAt(10) === ""
    // Spec: Returns empty string for out of bounds
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.charAt(allocator, 10);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "ECMAScript compliance - charAt with negative index" {
    // JavaScript: "hello".charAt(-1) === ""
    // Spec: Negative indices return empty string
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.charAt(allocator, -1);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "ECMAScript compliance - at with negative indexing" {
    // JavaScript: "hello".at(-1) === "o"
    // Spec: Negative indices count from end
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.at(allocator, -1);

    try std.testing.expect(result != null);
    if (result) |r| {
        defer allocator.free(r);
        try std.testing.expectEqualStrings("o", r);
    }
}

test "ECMAScript compliance - charCodeAt with surrogate pairs" {
    // JavaScript: "😀".charCodeAt(0) === 0xD83D (high surrogate)
    // JavaScript: "😀".charCodeAt(1) === 0xDE00 (low surrogate)
    const str = zstring.ZString.init("😀");

    const high = str.charCodeAt(0);
    const low = str.charCodeAt(1);

    try std.testing.expect(high != null);
    try std.testing.expect(low != null);
    try std.testing.expectEqual(@as(u16, 0xD83D), high.?);
    try std.testing.expectEqual(@as(u16, 0xDE00), low.?);
}

test "ECMAScript compliance - codePointAt returns full code point" {
    // JavaScript: "😀".codePointAt(0) === 0x1F600
    const str = zstring.ZString.init("😀");

    const codePoint = str.codePointAt(0);

    try std.testing.expect(codePoint != null);
    try std.testing.expectEqual(@as(u21, 0x1F600), codePoint.?);
}

// ============================================================================
// Search Methods - ECMAScript Compliance
// ============================================================================

test "ECMAScript compliance - indexOf with empty search" {
    // JavaScript: "hello".indexOf("") === 0
    // JavaScript: "hello".indexOf("", 3) === 3
    const str = zstring.ZString.init("hello");

    const result1 = str.indexOf("", null);
    try std.testing.expectEqual(@as(isize, 0), result1);

    const result2 = str.indexOf("", 3);
    try std.testing.expectEqual(@as(isize, 3), result2);
}

test "ECMAScript compliance - lastIndexOf with empty search" {
    // JavaScript: "hello".lastIndexOf("") === 5 (length of string)
    const str = zstring.ZString.init("hello");

    const result = str.lastIndexOf("", null);
    try std.testing.expectEqual(@as(isize, 5), result);
}

test "ECMAScript compliance - includes is case sensitive" {
    // JavaScript: "Hello".includes("hello") === false
    const str = zstring.ZString.init("Hello");

    const result = str.includes("hello", null);
    try std.testing.expect(!result);
}

test "ECMAScript compliance - startsWith with position" {
    // JavaScript: "hello world".startsWith("world", 6) === true
    const str = zstring.ZString.init("hello world");

    const result = str.startsWith("world", 6);
    try std.testing.expect(result);
}

test "ECMAScript compliance - endsWith with length parameter" {
    // JavaScript: "hello world".endsWith("hello", 5) === true
    // Treats string as if it were only 5 characters long
    const str = zstring.ZString.init("hello world");

    const result = str.endsWith("hello", 5);
    try std.testing.expect(result);
}

// ============================================================================
// Transform Methods - ECMAScript Compliance
// ============================================================================

test "ECMAScript compliance - slice with negative indices" {
    // JavaScript: "hello".slice(-2) === "lo"
    // JavaScript: "hello".slice(1, -1) === "ell"
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");

    const result1 = try str.slice(allocator, -2, null);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("lo", result1);

    const result2 = try str.slice(allocator, 1, -1);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("ell", result2);
}

test "ECMAScript compliance - substring swaps indices" {
    // JavaScript: "hello".substring(3, 1) === "el" (same as substring(1, 3))
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");

    const result = try str.substring(allocator, 3, 1);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("el", result);
}

test "ECMAScript compliance - substring treats negative as 0" {
    // JavaScript: "hello".substring(-2) === "hello" (same as substring(0))
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");

    const result = try str.substring(allocator, -2, null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "ECMAScript compliance - repeat with 0" {
    // JavaScript: "abc".repeat(0) === ""
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("abc");

    const result = try str.repeat(allocator, 0);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "ECMAScript compliance - concat multiple strings" {
    // JavaScript: "a".concat("b", "c", "d") === "abcd"
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("a");

    const strings = [_][]const u8{ "b", "c", "d" };
    const result = try str.concat(allocator, &strings);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abcd", result);
}

// ============================================================================
// Padding Methods - ECMAScript Compliance
// ============================================================================

test "ECMAScript compliance - padStart with default pad" {
    // JavaScript: "5".padStart(3) === "  5"
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("5");

    const result = try str.padStart(allocator, 3, null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("  5", result);
}

test "ECMAScript compliance - padEnd truncates long pad string" {
    // JavaScript: "abc".padEnd(10, "0123456789") === "abc0123456"
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("abc");

    const result = try str.padEnd(allocator, 10, "0123456789");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abc0123456", result);
}

test "ECMAScript compliance - padStart no padding if already long enough" {
    // JavaScript: "hello".padStart(3) === "hello"
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");

    const result = try str.padStart(allocator, 3, null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

// ============================================================================
// Split Methods - ECMAScript Compliance
// ============================================================================

test "ECMAScript compliance - split with undefined separator" {
    // JavaScript: "hello".split() === ["hello"]
    // Returns array with entire string
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");

    const result = try str.split(allocator, null, null);
    defer zstring.ZString.freeSplitResult(allocator, result);

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqualStrings("hello", result[0]);
}

test "ECMAScript compliance - split with empty separator" {
    // JavaScript: "hi".split("") === ["h", "i"]
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hi");

    const result = try str.split(allocator, "", null);
    defer zstring.ZString.freeSplitResult(allocator, result);

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqualStrings("h", result[0]);
    try std.testing.expectEqualStrings("i", result[1]);
}

test "ECMAScript compliance - split with limit" {
    // JavaScript: "a,b,c,d".split(",", 2) === ["a", "b"]
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("a,b,c,d");

    const result = try str.split(allocator, ",", 2);
    defer zstring.ZString.freeSplitResult(allocator, result);

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("b", result[1]);
}

// ============================================================================
// Case Conversion - ECMAScript Compliance
// ============================================================================

test "ECMAScript compliance - toLowerCase preserves length" {
    // JavaScript: "HELLO".toLowerCase().length === 5
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("HELLO");

    const result = try str.toLowerCase(allocator);
    defer allocator.free(result);

    const result_str = zstring.ZString.init(result);
    var result_str_mut = result_str;
    try std.testing.expectEqual(@as(usize, 5), result_str_mut.length());
}

test "ECMAScript compliance - toUpperCase with accented characters" {
    // JavaScript: "café".toUpperCase() === "CAFÉ"
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("café");

    const result = try str.toUpperCase(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("CAFÉ", result);
}

// ============================================================================
// Utility Methods - ECMAScript Compliance
// ============================================================================

test "ECMAScript compliance - localeCompare returns consistent ordering" {
    // JavaScript: "a".localeCompare("b") < 0
    // JavaScript: "b".localeCompare("a") > 0
    // JavaScript: "a".localeCompare("a") === 0

    const str1 = zstring.ZString.init("a");
    const str2 = zstring.ZString.init("b");

    const result1 = str1.localeCompare("b", null, null);
    const result2 = str2.localeCompare("a", null, null);
    const result3 = str1.localeCompare("a", null, null);

    try std.testing.expect(result1 < 0);
    try std.testing.expect(result2 > 0);
    try std.testing.expectEqual(@as(isize, 0), result3);
}

// ============================================================================
// Regex Methods - ECMAScript Compliance
// ============================================================================

test "ECMAScript compliance - search returns index or -1" {
    // JavaScript: "hello world".search(/world/) === 6
    // JavaScript: "hello world".search(/xyz/) === -1
    const allocator = std.testing.allocator;

    const str1 = zstring.ZString.init("hello world");
    const result1 = try str1.searchRegex(allocator, "world");
    try std.testing.expectEqual(@as(isize, 6), result1);

    const str2 = zstring.ZString.init("hello world");
    const result2 = try str2.searchRegex(allocator, "xyz");
    try std.testing.expectEqual(@as(isize, -1), result2);
}

test "ECMAScript compliance - match returns null when no match" {
    // JavaScript: "hello".match(/xyz/) === null
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.matchRegex(allocator, "xyz");

    try std.testing.expect(result == null);
}

test "ECMAScript compliance - replace only replaces first occurrence" {
    // JavaScript: "test test test".replace("test", "TEST") === "TEST test test"
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("test test test");
    const result = try str.replaceRegex(allocator, "test", "TEST");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("TEST test test", result);
}

test "ECMAScript compliance - replaceAll replaces all occurrences" {
    // JavaScript: "test test test".replaceAll("test", "TEST") === "TEST TEST TEST"
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("test test test");
    const result = try str.replaceAllRegex(allocator, "test", "TEST");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("TEST TEST TEST", result);
}

// ============================================================================
// UTF-16 Compliance Tests
// ============================================================================

test "ECMAScript compliance - length counts UTF-16 code units" {
    // JavaScript: "😀".length === 2 (surrogate pair)
    // JavaScript: "café".length === 4
    // JavaScript: "hello".length === 5

    var emoji = zstring.ZString.init("😀");
    try std.testing.expectEqual(@as(usize, 2), emoji.length());

    var accented = zstring.ZString.init("café");
    try std.testing.expectEqual(@as(usize, 4), accented.length());

    var ascii = zstring.ZString.init("hello");
    try std.testing.expectEqual(@as(usize, 5), ascii.length());
}

test "ECMAScript compliance - slice with emoji boundaries" {
    // JavaScript: "😀😃".slice(0, 2) === "😀"
    // Each emoji is 2 UTF-16 code units
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("😀😃");

    const result = try str.slice(allocator, 0, 2);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("😀", result);
}

// ============================================================================
// Empty String Edge Cases
// ============================================================================

test "ECMAScript compliance - empty string operations" {
    // JavaScript: "".charAt(0) === ""
    // JavaScript: "".indexOf("") === 0
    // JavaScript: "".slice(0) === ""
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("");

    const char = try str.charAt(allocator, 0);
    defer allocator.free(char);
    try std.testing.expectEqualStrings("", char);

    const idx = str.indexOf("", null);
    try std.testing.expectEqual(@as(isize, 0), idx);

    const sliced = try str.slice(allocator, 0, null);
    defer allocator.free(sliced);
    try std.testing.expectEqualStrings("", sliced);
}

// ============================================================================
// Type Coercion and Special Values
// ============================================================================

test "ECMAScript compliance - charCodeAt returns null for out of bounds" {
    // JavaScript: "hello".charCodeAt(10) returns NaN
    // In our implementation, we return null (which maps to undefined/NaN in JS context)
    const str = zstring.ZString.init("hello");

    const result = str.charCodeAt(10);
    try std.testing.expect(result == null);
}

test "ECMAScript compliance - at returns null for out of bounds" {
    // JavaScript: "hello".at(10) === undefined
    // We return null which maps to undefined
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");

    const result = try str.at(allocator, 10);
    try std.testing.expect(result == null);
}

// ============================================================================
// Unicode Normalization - ECMAScript Compliance
// ============================================================================

test "ECMAScript compliance - normalize default form is NFC" {
    // JavaScript: "café".normalize() === "café".normalize("NFC")
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("café");

    const result1 = try str.normalize(allocator, null);
    defer allocator.free(result1);

    const result2 = try str.normalize(allocator, "NFC");
    defer allocator.free(result2);

    try std.testing.expectEqualStrings(result1, result2);
}

test "ECMAScript compliance - normalize NFD decomposes accented characters" {
    // JavaScript: "é".normalize("NFD") produces decomposed form
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("é");

    const result = try str.normalize(allocator, "NFD");
    defer allocator.free(result);

    // Decomposed form should be longer (e + combining mark)
    try std.testing.expect(result.len > "é".len);
}

test "ECMAScript compliance - normalize NFC composes combining characters" {
    // JavaScript: combining characters should be composed in NFC
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("café");

    const result = try str.normalize(allocator, "NFC");
    defer allocator.free(result);

    try std.testing.expect(result.len > 0);
}

test "ECMAScript compliance - normalize ASCII unchanged in all forms" {
    // JavaScript: ASCII strings should be unchanged by normalization
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");

    const nfc = try str.normalize(allocator, "NFC");
    defer allocator.free(nfc);
    try std.testing.expectEqualStrings("hello", nfc);

    const nfd = try str.normalize(allocator, "NFD");
    defer allocator.free(nfd);
    try std.testing.expectEqualStrings("hello", nfd);

    const nfkc = try str.normalize(allocator, "NFKC");
    defer allocator.free(nfkc);
    try std.testing.expectEqualStrings("hello", nfkc);

    const nfkd = try str.normalize(allocator, "NFKD");
    defer allocator.free(nfkd);
    try std.testing.expectEqualStrings("hello", nfkd);
}

test "ECMAScript compliance - normalize empty string" {
    // JavaScript: "".normalize() === ""
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("");

    const result = try str.normalize(allocator, null);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "ECMAScript compliance - normalize with common accented characters" {
    // Test with various accented characters
    const allocator = std.testing.allocator;

    const test_cases = [_][]const u8{
        "Café",
        "naïve",
        "résumé",
        "Zürich",
        "São Paulo",
    };

    for (test_cases) |input| {
        const str = zstring.ZString.init(input);

        const nfc = try str.normalize(allocator, "NFC");
        defer allocator.free(nfc);
        try std.testing.expect(nfc.len > 0);

        const nfd = try str.normalize(allocator, "NFD");
        defer allocator.free(nfd);
        try std.testing.expect(nfd.len > 0);
    }
}
