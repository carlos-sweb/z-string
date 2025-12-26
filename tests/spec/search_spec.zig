const std = @import("std");
const zstring = @import("zstring");

// ============================================================================
// indexOf() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.indexof
// ============================================================================

test "spec - indexOf basic search" {
    const str = zstring.ZString.init("hello world");

    // "hello world".indexOf("world") === 6
    try std.testing.expectEqual(@as(isize, 6), str.indexOf("world", null));

    // "hello world".indexOf("o") === 4
    try std.testing.expectEqual(@as(isize, 4), str.indexOf("o", null));

    // "hello world".indexOf("hello") === 0
    try std.testing.expectEqual(@as(isize, 0), str.indexOf("hello", null));
}

test "spec - indexOf with position parameter" {
    const str = zstring.ZString.init("hello world");

    // "hello world".indexOf("o", 0) === 4
    try std.testing.expectEqual(@as(isize, 4), str.indexOf("o", 0));

    // "hello world".indexOf("o", 5) === 7
    try std.testing.expectEqual(@as(isize, 7), str.indexOf("o", 5));

    // "hello world".indexOf("o", 8) === -1 (no more 'o' after position 8)
    try std.testing.expectEqual(@as(isize, -1), str.indexOf("o", 8));
}

test "spec - indexOf not found returns -1" {
    const str = zstring.ZString.init("hello world");

    // "hello world".indexOf("xyz") === -1
    try std.testing.expectEqual(@as(isize, -1), str.indexOf("xyz", null));

    // "hello world".indexOf("Hello") === -1 (case sensitive)
    try std.testing.expectEqual(@as(isize, -1), str.indexOf("Hello", null));
}

test "spec - indexOf empty string" {
    const str = zstring.ZString.init("hello");

    // "hello".indexOf("") === 0
    try std.testing.expectEqual(@as(isize, 0), str.indexOf("", null));

    // "hello".indexOf("", 2) === 2
    try std.testing.expectEqual(@as(isize, 2), str.indexOf("", 2));

    // Empty string searching empty string
    const empty = zstring.ZString.init("");
    try std.testing.expectEqual(@as(isize, 0), empty.indexOf("", null));
}

test "spec - indexOf with emoji (UTF-16 compliance)" {
    // "😀😃" has length 4 in UTF-16 (each emoji is 2 code units)
    const str = zstring.ZString.init("😀😃");

    // "😀😃".indexOf("😃") === 2 (starts at UTF-16 index 2)
    try std.testing.expectEqual(@as(isize, 2), str.indexOf("😃", null));

    // "😀😃".indexOf("😀") === 0
    try std.testing.expectEqual(@as(isize, 0), str.indexOf("😀", null));
}

test "spec - indexOf with mixed content" {
    const str = zstring.ZString.init("hello😀world");

    // h=0, e=1, l=2, l=3, o=4, 😀=5-6, w=7, o=8, r=9, l=10, d=11
    try std.testing.expectEqual(@as(isize, 0), str.indexOf("hello", null));
    try std.testing.expectEqual(@as(isize, 5), str.indexOf("😀", null));
    try std.testing.expectEqual(@as(isize, 7), str.indexOf("world", null));
}

// ============================================================================
// lastIndexOf() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.lastindexof
// ============================================================================

test "spec - lastIndexOf basic search" {
    const str = zstring.ZString.init("hello world hello");

    // "hello world hello".lastIndexOf("hello") === 12
    try std.testing.expectEqual(@as(isize, 12), str.lastIndexOf("hello", null));

    // "hello world hello".lastIndexOf("o") === 16
    try std.testing.expectEqual(@as(isize, 16), str.lastIndexOf("o", null));

    // "hello world hello".lastIndexOf("world") === 6
    try std.testing.expectEqual(@as(isize, 6), str.lastIndexOf("world", null));
}

test "spec - lastIndexOf with position parameter" {
    const str = zstring.ZString.init("hello world hello");

    // "hello world hello".lastIndexOf("hello", 10) === 0 (find first, not second)
    try std.testing.expectEqual(@as(isize, 0), str.lastIndexOf("hello", 10));

    // "hello world hello".lastIndexOf("o", 6) === 4
    try std.testing.expectEqual(@as(isize, 4), str.lastIndexOf("o", 6));

    // "hello world hello".lastIndexOf("o", 7) === 7
    try std.testing.expectEqual(@as(isize, 7), str.lastIndexOf("o", 7));
}

test "spec - lastIndexOf not found returns -1" {
    const str = zstring.ZString.init("hello world");

    // "hello world".lastIndexOf("xyz") === -1
    try std.testing.expectEqual(@as(isize, -1), str.lastIndexOf("xyz", null));
}

test "spec - lastIndexOf empty string" {
    const str = zstring.ZString.init("hello");

    // "hello".lastIndexOf("") === 5 (end of string)
    try std.testing.expectEqual(@as(isize, 5), str.lastIndexOf("", null));

    // "hello".lastIndexOf("", 2) === 2
    try std.testing.expectEqual(@as(isize, 2), str.lastIndexOf("", 2));
}

// ============================================================================
// includes() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.includes
// ============================================================================

test "spec - includes basic search" {
    const str = zstring.ZString.init("hello world");

    // "hello world".includes("world") === true
    try std.testing.expect(str.includes("world", null));

    // "hello world".includes("hello") === true
    try std.testing.expect(str.includes("hello", null));

    // "hello world".includes("o") === true
    try std.testing.expect(str.includes("o", null));

    // "hello world".includes("xyz") === false
    try std.testing.expect(!str.includes("xyz", null));
}

test "spec - includes with position parameter" {
    const str = zstring.ZString.init("hello world");

    // "hello world".includes("world", 0) === true
    try std.testing.expect(str.includes("world", 0));

    // "hello world".includes("world", 7) === false (starts search after "world")
    try std.testing.expect(!str.includes("world", 7));

    // "hello world".includes("hello", 1) === false
    try std.testing.expect(!str.includes("hello", 1));
}

test "spec - includes empty string" {
    const str = zstring.ZString.init("hello");

    // "hello".includes("") === true
    try std.testing.expect(str.includes("", null));

    // Empty string includes empty string
    const empty = zstring.ZString.init("");
    try std.testing.expect(empty.includes("", null));
}

test "spec - includes case sensitive" {
    const str = zstring.ZString.init("Hello World");

    // "Hello World".includes("hello") === false (case sensitive)
    try std.testing.expect(!str.includes("hello", null));

    // "Hello World".includes("Hello") === true
    try std.testing.expect(str.includes("Hello", null));
}

// ============================================================================
// startsWith() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.startswith
// ============================================================================

test "spec - startsWith basic functionality" {
    const str = zstring.ZString.init("hello world");

    // "hello world".startsWith("hello") === true
    try std.testing.expect(str.startsWith("hello", null));

    // "hello world".startsWith("world") === false
    try std.testing.expect(!str.startsWith("world", null));

    // "hello world".startsWith("h") === true
    try std.testing.expect(str.startsWith("h", null));
}

test "spec - startsWith with position parameter" {
    const str = zstring.ZString.init("hello world");

    // "hello world".startsWith("world", 6) === true
    try std.testing.expect(str.startsWith("world", 6));

    // "hello world".startsWith("hello", 0) === true
    try std.testing.expect(str.startsWith("hello", 0));

    // "hello world".startsWith("hello", 1) === false
    try std.testing.expect(!str.startsWith("hello", 1));

    // "hello world".startsWith("o", 4) === true
    try std.testing.expect(str.startsWith("o", 4));
}

test "spec - startsWith empty string" {
    const str = zstring.ZString.init("hello");

    // "hello".startsWith("") === true
    try std.testing.expect(str.startsWith("", null));

    // "hello".startsWith("", 3) === true
    try std.testing.expect(str.startsWith("", 3));
}

test "spec - startsWith with emoji" {
    const str = zstring.ZString.init("😀hello");

    // "😀hello".startsWith("😀") === true
    try std.testing.expect(str.startsWith("😀", null));

    // "😀hello".startsWith("hello", 2) === true (emoji is 2 UTF-16 units)
    try std.testing.expect(str.startsWith("hello", 2));
}

test "spec - startsWith exact match" {
    const str = zstring.ZString.init("hello");

    // "hello".startsWith("hello") === true (entire string)
    try std.testing.expect(str.startsWith("hello", null));

    // "hello".startsWith("hello world") === false (longer than string)
    try std.testing.expect(!str.startsWith("hello world", null));
}

// ============================================================================
// endsWith() Spec Compliance Tests
// https://tc39.es/ecma262/2025/#sec-string.prototype.endswith
// ============================================================================

test "spec - endsWith basic functionality" {
    const str = zstring.ZString.init("hello world");

    // "hello world".endsWith("world") === true
    try std.testing.expect(str.endsWith("world", null));

    // "hello world".endsWith("hello") === false
    try std.testing.expect(!str.endsWith("hello", null));

    // "hello world".endsWith("d") === true
    try std.testing.expect(str.endsWith("d", null));
}

test "spec - endsWith with length parameter" {
    const str = zstring.ZString.init("hello world");

    // "hello world".endsWith("hello", 5) === true (as if string was "hello")
    try std.testing.expect(str.endsWith("hello", 5));

    // "hello world".endsWith("world", 11) === true
    try std.testing.expect(str.endsWith("world", 11));

    // "hello world".endsWith("world", 5) === false
    try std.testing.expect(!str.endsWith("world", 5));

    // "hello world".endsWith("o", 5) === true
    try std.testing.expect(str.endsWith("o", 5));
}

test "spec - endsWith empty string" {
    const str = zstring.ZString.init("hello");

    // "hello".endsWith("") === true
    try std.testing.expect(str.endsWith("", null));

    // "hello".endsWith("", 3) === true
    try std.testing.expect(str.endsWith("", 3));
}

test "spec - endsWith with emoji" {
    const str = zstring.ZString.init("hello😀");

    // "hello😀".endsWith("😀") === true
    try std.testing.expect(str.endsWith("😀", null));

    // "hello😀".endsWith("o😀") === true
    try std.testing.expect(str.endsWith("o😀", null));

    // "hello😀".endsWith("hello", 5) === true
    try std.testing.expect(str.endsWith("hello", 5));
}

test "spec - endsWith exact match" {
    const str = zstring.ZString.init("hello");

    // "hello".endsWith("hello") === true (entire string)
    try std.testing.expect(str.endsWith("hello", null));

    // "hello".endsWith("xhello") === false (longer than string)
    try std.testing.expect(!str.endsWith("xhello", null));
}

// ============================================================================
// Cross-method compatibility tests
// ============================================================================

test "spec - indexOf vs includes consistency" {
    const str = zstring.ZString.init("hello world");

    // If indexOf returns >= 0, includes should return true
    const idx = str.indexOf("world", null);
    const inc = str.includes("world", null);
    try std.testing.expect((idx >= 0) == inc);

    // If indexOf returns -1, includes should return false
    const idx2 = str.indexOf("xyz", null);
    const inc2 = str.includes("xyz", null);
    try std.testing.expect((idx2 == -1) == !inc2);
}

test "spec - startsWith vs indexOf at position 0" {
    const str = zstring.ZString.init("hello world");

    // If startsWith("hello") is true, indexOf("hello") should be 0
    try std.testing.expect(str.startsWith("hello", null));
    try std.testing.expectEqual(@as(isize, 0), str.indexOf("hello", null));

    // If startsWith("world") is false, indexOf("world") should not be 0
    try std.testing.expect(!str.startsWith("world", null));
    try std.testing.expect(str.indexOf("world", null) != 0);
}

test "spec - multiple search methods on same string" {
    const str = zstring.ZString.init("JavaScript");

    // indexOf
    try std.testing.expectEqual(@as(isize, 0), str.indexOf("Java", null));
    try std.testing.expectEqual(@as(isize, 4), str.indexOf("Script", null));

    // lastIndexOf
    try std.testing.expectEqual(@as(isize, 0), str.lastIndexOf("Java", null));
    try std.testing.expectEqual(@as(isize, 4), str.lastIndexOf("Script", null));

    // includes
    try std.testing.expect(str.includes("Java", null));
    try std.testing.expect(str.includes("Script", null));
    try std.testing.expect(!str.includes("Python", null));

    // startsWith
    try std.testing.expect(str.startsWith("Java", null));
    try std.testing.expect(!str.startsWith("Script", null));
    try std.testing.expect(str.startsWith("Script", 4));

    // endsWith
    try std.testing.expect(str.endsWith("Script", null));
    try std.testing.expect(!str.endsWith("Java", null));
    try std.testing.expect(str.endsWith("Java", 4));
}
