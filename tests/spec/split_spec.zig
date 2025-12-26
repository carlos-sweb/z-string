const std = @import("std");
const zstring = @import("zstring");

// ============================================================================
// Split Spec Tests
// ============================================================================

test "spec - split: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.split
    //
    // JavaScript behavior:
    // "a,b,c".split(",") -> ["a", "b", "c"]
    // "hello world".split(" ") -> ["hello", "world"]

    const allocator = std.testing.allocator;

    const str1 = zstring.ZString.init("a,b,c");
    const result1 = try str1.split(allocator, ",", null);
    defer zstring.ZString.freeSplitResult(allocator, result1);
    try std.testing.expectEqual(@as(usize, 3), result1.len);
    try std.testing.expectEqualStrings("a", result1[0]);
    try std.testing.expectEqualStrings("b", result1[1]);
    try std.testing.expectEqualStrings("c", result1[2]);

    const str2 = zstring.ZString.init("hello world");
    const result2 = try str2.split(allocator, " ", null);
    defer zstring.ZString.freeSplitResult(allocator, result2);
    try std.testing.expectEqual(@as(usize, 2), result2.len);
    try std.testing.expectEqualStrings("hello", result2[0]);
    try std.testing.expectEqualStrings("world", result2[1]);
}

test "spec - split: empty separator" {
    // JavaScript behavior:
    // "hello".split("") -> ["h", "e", "l", "l", "o"]
    //
    // Splits into individual characters (UTF-8 code points)

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.split(allocator, "", null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqualStrings("h", result[0]);
    try std.testing.expectEqualStrings("e", result[1]);
    try std.testing.expectEqualStrings("l", result[2]);
    try std.testing.expectEqualStrings("l", result[3]);
    try std.testing.expectEqualStrings("o", result[4]);
}

test "spec - split: undefined separator" {
    // JavaScript behavior:
    // "hello".split(undefined) -> ["hello"]
    // "hello".split() -> ["hello"]
    //
    // Returns array with the whole string

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.split(allocator, null, null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqualStrings("hello", result[0]);
}

test "spec - split: with limit" {
    // JavaScript behavior:
    // "a,b,c,d".split(",", 2) -> ["a", "b"]
    // "hello".split("", 3) -> ["h", "e", "l"]

    const allocator = std.testing.allocator;

    const str1 = zstring.ZString.init("a,b,c,d");
    const result1 = try str1.split(allocator, ",", 2);
    defer zstring.ZString.freeSplitResult(allocator, result1);
    try std.testing.expectEqual(@as(usize, 2), result1.len);
    try std.testing.expectEqualStrings("a", result1[0]);
    try std.testing.expectEqualStrings("b", result1[1]);

    const str2 = zstring.ZString.init("hello");
    const result2 = try str2.split(allocator, "", 3);
    defer zstring.ZString.freeSplitResult(allocator, result2);
    try std.testing.expectEqual(@as(usize, 3), result2.len);
    try std.testing.expectEqualStrings("h", result2[0]);
    try std.testing.expectEqualStrings("e", result2[1]);
    try std.testing.expectEqualStrings("l", result2[2]);
}

test "spec - split: limit zero" {
    // JavaScript behavior:
    // "a,b,c".split(",", 0) -> []

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("a,b,c");
    const result = try str.split(allocator, ",", 0);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "spec - split: separator not found" {
    // JavaScript behavior:
    // "hello".split(",") -> ["hello"]

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello");
    const result = try str.split(allocator, ",", null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqualStrings("hello", result[0]);
}

test "spec - split: empty string with separator" {
    // JavaScript behavior:
    // "".split(",") -> [""]

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("");
    const result = try str.split(allocator, ",", null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqualStrings("", result[0]);
}

test "spec - split: empty string with empty separator" {
    // JavaScript behavior:
    // "".split("") -> []

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("");
    const result = try str.split(allocator, "", null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "spec - split: separator at start" {
    // JavaScript behavior:
    // ",a,b".split(",") -> ["", "a", "b"]

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init(",a,b");
    const result = try str.split(allocator, ",", null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("", result[0]);
    try std.testing.expectEqualStrings("a", result[1]);
    try std.testing.expectEqualStrings("b", result[2]);
}

test "spec - split: separator at end" {
    // JavaScript behavior:
    // "a,b,".split(",") -> ["a", "b", ""]

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("a,b,");
    const result = try str.split(allocator, ",", null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("b", result[1]);
    try std.testing.expectEqualStrings("", result[2]);
}

test "spec - split: consecutive separators" {
    // JavaScript behavior:
    // "a,,b".split(",") -> ["a", "", "b"]

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("a,,b");
    const result = try str.split(allocator, ",", null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("", result[1]);
    try std.testing.expectEqualStrings("b", result[2]);
}

test "spec - split: multi-character separator" {
    // JavaScript behavior:
    // "a::b::c".split("::") -> ["a", "b", "c"]

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("a::b::c");
    const result = try str.split(allocator, "::", null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("b", result[1]);
    try std.testing.expectEqualStrings("c", result[2]);
}

test "spec - split: complex multi-character separator" {
    // JavaScript behavior:
    // "hello<br>world<br>test".split("<br>") -> ["hello", "world", "test"]

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("hello<br>world<br>test");
    const result = try str.split(allocator, "<br>", null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("hello", result[0]);
    try std.testing.expectEqualStrings("world", result[1]);
    try std.testing.expectEqualStrings("test", result[2]);
}

test "spec - split: Unicode characters" {
    // JavaScript behavior:
    // "café,thé".split(",") -> ["café", "thé"]

    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("café,thé");
    const result = try str.split(allocator, ",", null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqualStrings("café", result[0]);
    try std.testing.expectEqualStrings("thé", result[1]);
}

test "spec - split: Emoji characters" {
    // Emoji splitting with empty separator
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("a😀b");
    const result = try str.split(allocator, "", null);
    defer zstring.ZString.freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("😀", result[1]);
    try std.testing.expectEqualStrings("b", result[2]);
}

test "spec - split: real-world examples" {
    const allocator = std.testing.allocator;

    // CSV-like data
    const csv = zstring.ZString.init("John,Doe,30,Engineer");
    const csv_result = try csv.split(allocator, ",", null);
    defer zstring.ZString.freeSplitResult(allocator, csv_result);
    try std.testing.expectEqual(@as(usize, 4), csv_result.len);
    try std.testing.expectEqualStrings("John", csv_result[0]);
    try std.testing.expectEqualStrings("Doe", csv_result[1]);
    try std.testing.expectEqualStrings("30", csv_result[2]);
    try std.testing.expectEqualStrings("Engineer", csv_result[3]);

    // Path splitting
    const path = zstring.ZString.init("/usr/local/bin");
    const path_result = try path.split(allocator, "/", null);
    defer zstring.ZString.freeSplitResult(allocator, path_result);
    try std.testing.expectEqual(@as(usize, 4), path_result.len);
    try std.testing.expectEqualStrings("", path_result[0]); // Leading /
    try std.testing.expectEqualStrings("usr", path_result[1]);
    try std.testing.expectEqualStrings("local", path_result[2]);
    try std.testing.expectEqualStrings("bin", path_result[3]);

    // Sentence splitting
    const sentence = zstring.ZString.init("Hello world this is a test");
    const words = try sentence.split(allocator, " ", null);
    defer zstring.ZString.freeSplitResult(allocator, words);
    try std.testing.expectEqual(@as(usize, 6), words.len);
    try std.testing.expectEqualStrings("Hello", words[0]);
    try std.testing.expectEqualStrings("world", words[1]);
    try std.testing.expectEqualStrings("this", words[2]);
    try std.testing.expectEqualStrings("is", words[3]);
    try std.testing.expectEqualStrings("a", words[4]);
    try std.testing.expectEqualStrings("test", words[5]);
}

test "spec - split: edge cases" {
    const allocator = std.testing.allocator;

    // Only separator
    const only_sep = zstring.ZString.init(",");
    const only_sep_result = try only_sep.split(allocator, ",", null);
    defer zstring.ZString.freeSplitResult(allocator, only_sep_result);
    try std.testing.expectEqual(@as(usize, 2), only_sep_result.len);
    try std.testing.expectEqualStrings("", only_sep_result[0]);
    try std.testing.expectEqualStrings("", only_sep_result[1]);

    // Multiple consecutive separators
    const multi_sep = zstring.ZString.init(",,,");
    const multi_sep_result = try multi_sep.split(allocator, ",", null);
    defer zstring.ZString.freeSplitResult(allocator, multi_sep_result);
    try std.testing.expectEqual(@as(usize, 4), multi_sep_result.len);
    try std.testing.expectEqualStrings("", multi_sep_result[0]);
    try std.testing.expectEqualStrings("", multi_sep_result[1]);
    try std.testing.expectEqualStrings("", multi_sep_result[2]);
    try std.testing.expectEqualStrings("", multi_sep_result[3]);
}
