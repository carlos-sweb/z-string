const std = @import("std");
const zstring = @import("zstring");

// ============================================================================
// Case Conversion Spec Tests
// ============================================================================

test "spec - toLowerCase: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.tolowercase
    //
    // JavaScript behavior:
    // "HELLO".toLowerCase() -> "hello"
    // "Hello World".toLowerCase() -> "hello world"

    const allocator = std.testing.allocator;

    const str1 = zstring.ZString.init("HELLO");
    const result1 = try str1.toLowerCase(allocator);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello", result1);

    const str2 = zstring.ZString.init("Hello World");
    const result2 = try str2.toLowerCase(allocator);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello world", result2);
}

test "spec - toLowerCase: already lowercase" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.toLowerCase(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "spec - toLowerCase: mixed case" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("HeLLo WoRLd");
    const result = try str.toLowerCase(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "spec - toLowerCase: with numbers" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("ABC123");
    const result = try str.toLowerCase(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abc123", result);
}

test "spec - toLowerCase: Unicode Latin" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("CAFÉ");
    const result = try str.toLowerCase(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("café", result);
}

test "spec - toLowerCase: empty string" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("");
    const result = try str.toLowerCase(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "spec - toUpperCase: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.touppercase
    //
    // JavaScript behavior:
    // "hello".toUpperCase() -> "HELLO"
    // "Hello World".toUpperCase() -> "HELLO WORLD"

    const allocator = std.testing.allocator;

    const str1 = zstring.ZString.init("hello");
    const result1 = try str1.toUpperCase(allocator);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("HELLO", result1);

    const str2 = zstring.ZString.init("Hello World");
    const result2 = try str2.toUpperCase(allocator);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("HELLO WORLD", result2);
}

test "spec - toUpperCase: already uppercase" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("HELLO");
    const result = try str.toUpperCase(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("HELLO", result);
}

test "spec - toUpperCase: mixed case" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("HeLLo WoRLd");
    const result = try str.toUpperCase(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("HELLO WORLD", result);
}

test "spec - toUpperCase: with numbers" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("abc123");
    const result = try str.toUpperCase(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("ABC123", result);
}

test "spec - toUpperCase: Unicode Latin" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("café");
    const result = try str.toUpperCase(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("CAFÉ", result);
}

test "spec - toUpperCase: empty string" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("");
    const result = try str.toUpperCase(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "spec - case conversion: round trip" {
    const allocator = std.testing.allocator;

    const original = zstring.ZString.init("Hello World");

    // To upper
    const upper = try original.toUpperCase(allocator);
    defer allocator.free(upper);
    try std.testing.expectEqualStrings("HELLO WORLD", upper);

    // To lower
    const upper_str = zstring.ZString.init(upper);
    const lower = try upper_str.toLowerCase(allocator);
    defer allocator.free(lower);
    try std.testing.expectEqualStrings("hello world", lower);
}

test "spec - toLocaleLowerCase: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.tolocalelowercase
    //
    // JavaScript behavior:
    // "HELLO".toLocaleLowerCase() -> "hello"

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("HELLO");
    const result = try str.toLocaleLowerCase(allocator, null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "spec - toLocaleUpperCase: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.tolocaleuppercase
    //
    // JavaScript behavior:
    // "hello".toLocaleUpperCase() -> "HELLO"

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.toLocaleUpperCase(allocator, null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("HELLO", result);
}

// ============================================================================
// Utility Methods Spec Tests
// ============================================================================

test "spec - toString: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.tostring
    //
    // JavaScript behavior:
    // "hello".toString() -> "hello"
    // Returns the primitive string value

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.toStringAlloc(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "spec - toString: empty string" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("");
    const result = try str.toStringAlloc(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "spec - toString: Unicode" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello 😀 world");
    const result = try str.toStringAlloc(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello 😀 world", result);
}

test "spec - valueOf: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.valueof
    //
    // JavaScript behavior:
    // "hello".valueOf() -> "hello"
    // Returns the primitive value

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.valueOfAlloc(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "spec - valueOf: empty string" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("");
    const result = try str.valueOfAlloc(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "spec - localeCompare: equal strings" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.localecompare
    //
    // JavaScript behavior:
    // "hello".localeCompare("hello") -> 0

    const str = zstring.ZString.init("hello");
    const result = str.localeCompare("hello", null, null);
    try std.testing.expectEqual(@as(isize, 0), result);
}

test "spec - localeCompare: first comes before second" {
    // "apple".localeCompare("banana") -> negative number

    const str = zstring.ZString.init("apple");
    const result = str.localeCompare("banana", null, null);
    try std.testing.expect(result < 0);
}

test "spec - localeCompare: first comes after second" {
    // "banana".localeCompare("apple") -> positive number

    const str = zstring.ZString.init("banana");
    const result = str.localeCompare("apple", null, null);
    try std.testing.expect(result > 0);
}

test "spec - localeCompare: case sensitive" {
    const str = zstring.ZString.init("a");
    const result = str.localeCompare("Z", null, null);
    // lowercase 'a' (97) comes after uppercase 'Z' (90)
    try std.testing.expect(result > 0);
}

test "spec - localeCompare: different lengths" {
    const str1 = zstring.ZString.init("abc");
    const result1 = str1.localeCompare("abcd", null, null);
    try std.testing.expect(result1 < 0);

    const str2 = zstring.ZString.init("abcd");
    const result2 = str2.localeCompare("abc", null, null);
    try std.testing.expect(result2 > 0);
}

test "spec - localeCompare: empty strings" {
    const str1 = zstring.ZString.init("");
    const result1 = str1.localeCompare("", null, null);
    try std.testing.expectEqual(@as(isize, 0), result1);

    const result2 = str1.localeCompare("a", null, null);
    try std.testing.expect(result2 < 0);

    const str2 = zstring.ZString.init("a");
    const result3 = str2.localeCompare("", null, null);
    try std.testing.expect(result3 > 0);
}

test "spec - normalize: default NFC" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.normalize
    //
    // JavaScript behavior:
    // "hello".normalize() -> "hello"
    // Default form is "NFC"

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.normalize(allocator, null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "spec - normalize: explicit NFC" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.normalize(allocator, "NFC");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "spec - normalize: NFD" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.normalize(allocator, "NFD");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "spec - normalize: NFKC" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.normalize(allocator, "NFKC");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "spec - normalize: NFKD" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.normalize(allocator, "NFKD");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "spec - normalize: empty string" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("");
    const result = try str.normalize(allocator, null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

// ============================================================================
// Real-world use cases
// ============================================================================

test "spec - case conversion: real-world use cases" {
    const allocator = std.testing.allocator;

    // Email normalization (convert to lowercase)
    const email = zstring.ZString.init("User@Example.COM");
    const normalized_email = try email.toLowerCase(allocator);
    defer allocator.free(normalized_email);
    try std.testing.expectEqualStrings("user@example.com", normalized_email);

    // Title formatting (convert to uppercase)
    const title = zstring.ZString.init("important notice");
    const title_upper = try title.toUpperCase(allocator);
    defer allocator.free(title_upper);
    try std.testing.expectEqualStrings("IMPORTANT NOTICE", title_upper);
}

test "spec - localeCompare: sorting strings" {
    // Testing alphabetical sorting
    const strings = [_][]const u8{ "banana", "apple", "cherry" };

    const str1 = zstring.ZString.init(strings[0]);
    const str2 = zstring.ZString.init(strings[1]);

    // banana > apple
    try std.testing.expect(str1.localeCompare(strings[1], null, null) > 0);

    // apple < banana
    try std.testing.expect(str2.localeCompare(strings[0], null, null) < 0);

    // banana < cherry
    try std.testing.expect(str1.localeCompare(strings[2], null, null) < 0);
}
