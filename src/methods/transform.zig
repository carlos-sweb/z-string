const std = @import("std");
const utf16 = @import("../core/utf16.zig");
const Allocator = std.mem.Allocator;

/// String.prototype.slice(start, end)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.slice
///
/// Extracts a section of this string and returns it as a new string.
/// Supports negative indices (count from end).
///
/// Key differences from substring():
/// - Negative indices are supported (count from end)
/// - If start > end, returns empty string (doesn't swap)
///
/// Examples:
///   slice("hello", 1, 4) -> "ell"
///   slice("hello", -2, null) -> "lo"
///   slice("hello", 3, 1) -> "" (start > end)
pub fn slice(allocator: Allocator, str: []const u8, start: isize, end: ?isize) ![]u8 {
    const len = utf16.lengthUtf16(str);
    const len_signed: isize = @intCast(len);

    // Normalize start index
    var real_start: isize = start;
    if (real_start < 0) {
        real_start = @max(0, len_signed + start);
    } else {
        real_start = @min(real_start, len_signed);
    }

    // Normalize end index
    var real_end: isize = end orelse len_signed;
    if (real_end < 0) {
        real_end = @max(0, len_signed + real_end);
    } else {
        real_end = @min(real_end, len_signed);
    }

    // If start >= end, return empty string
    if (real_start >= real_end) {
        return allocator.alloc(u8, 0);
    }

    const start_usize: usize = @intCast(real_start);
    const end_usize: usize = @intCast(real_end);

    // Convert UTF-16 indices to byte indices
    const start_byte = utf16.utf16IndexToByte(str, start_usize) catch {
        return allocator.alloc(u8, 0);
    };
    const end_byte = utf16.utf16IndexToByte(str, end_usize) catch {
        return allocator.alloc(u8, 0);
    };

    // Return the slice
    return allocator.dupe(u8, str[start_byte..end_byte]);
}

/// String.prototype.substring(start, end)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.substring
///
/// Returns the part of the string between start and end indices.
///
/// Key differences from slice():
/// - Negative indices are treated as 0
/// - If start > end, they are swapped
/// - Does not support negative indexing
///
/// Examples:
///   substring("hello", 1, 4) -> "ell"
///   substring("hello", -2, null) -> "hello" (negative treated as 0)
///   substring("hello", 3, 1) -> "el" (swapped to 1, 3)
pub fn substring(allocator: Allocator, str: []const u8, start: isize, end: ?isize) ![]u8 {
    const len = utf16.lengthUtf16(str);
    const len_signed: isize = @intCast(len);

    // Clamp start to [0, len]
    var real_start: isize = @max(0, @min(start, len_signed));

    // Clamp end to [0, len]
    var real_end: isize = if (end) |e|
        @max(0, @min(e, len_signed))
    else
        len_signed;

    // Swap if start > end (key difference from slice!)
    if (real_start > real_end) {
        const temp = real_start;
        real_start = real_end;
        real_end = temp;
    }

    const start_usize: usize = @intCast(real_start);
    const end_usize: usize = @intCast(real_end);

    // Convert UTF-16 indices to byte indices
    const start_byte = utf16.utf16IndexToByte(str, start_usize) catch {
        return allocator.alloc(u8, 0);
    };
    const end_byte = utf16.utf16IndexToByte(str, end_usize) catch {
        return allocator.alloc(u8, 0);
    };

    // Return the substring
    return allocator.dupe(u8, str[start_byte..end_byte]);
}

/// String.prototype.concat(...strings)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.concat
///
/// Combines the text of one or more strings and returns a new string.
///
/// Examples:
///   concat(allocator, "hello", &[_][]const u8{"world"}) -> "helloworld"
///   concat(allocator, "a", &[_][]const u8{"b", "c"}) -> "abc"
pub fn concat(allocator: Allocator, str: []const u8, strings: []const []const u8) ![]u8 {
    // Calculate total length
    var total_len: usize = str.len;
    for (strings) |s| {
        total_len += s.len;
    }

    // Allocate result buffer
    var result = try allocator.alloc(u8, total_len);
    errdefer allocator.free(result);

    // Copy the original string
    @memcpy(result[0..str.len], str);
    var pos: usize = str.len;

    // Append each additional string
    for (strings) |s| {
        @memcpy(result[pos .. pos + s.len], s);
        pos += s.len;
    }

    return result;
}

/// String.prototype.repeat(count)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.repeat
///
/// Constructs and returns a new string containing the specified number
/// of copies of this string concatenated together.
///
/// Examples:
///   repeat("abc", 0) -> ""
///   repeat("abc", 1) -> "abc"
///   repeat("abc", 3) -> "abcabcabc"
///   repeat("😀", 2) -> "😀😀"
pub fn repeat(allocator: Allocator, str: []const u8, count: isize) ![]u8 {
    // Spec: RangeError if count < 0 or count is infinity
    // In Zig, we return error for negative count
    if (count < 0) {
        return error.InvalidCount;
    }

    // Zero repetitions = empty string
    if (count == 0 or str.len == 0) {
        return allocator.alloc(u8, 0);
    }

    const count_usize: usize = @intCast(count);

    // Check for potential overflow
    if (count_usize > std.math.maxInt(usize) / str.len) {
        return error.OutOfMemory;
    }

    const total_len = str.len * count_usize;

    // Allocate result buffer
    var result = try allocator.alloc(u8, total_len);
    errdefer allocator.free(result);

    // Copy the string count times
    var i: usize = 0;
    while (i < count_usize) : (i += 1) {
        const start = i * str.len;
        @memcpy(result[start .. start + str.len], str);
    }

    return result;
}

// ============================================================================
// Tests
// ============================================================================

test "slice - basic functionality" {
    const allocator = std.testing.allocator;

    // "hello".slice(1, 4) -> "ell"
    const result1 = try slice(allocator, "hello", 1, 4);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("ell", result1);

    // "hello".slice(0, 5) -> "hello"
    const result2 = try slice(allocator, "hello", 0, 5);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello", result2);

    // "hello".slice(2, null) -> "llo" (to end)
    const result3 = try slice(allocator, "hello", 2, null);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("llo", result3);
}

test "slice - negative indices" {
    const allocator = std.testing.allocator;

    // "hello".slice(-2, null) -> "lo"
    const result1 = try slice(allocator, "hello", -2, null);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("lo", result1);

    // "hello".slice(-4, -1) -> "ell"
    const result2 = try slice(allocator, "hello", -4, -1);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("ell", result2);

    // "hello".slice(-5, null) -> "hello" (from start)
    const result3 = try slice(allocator, "hello", -5, null);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("hello", result3);
}

test "slice - start >= end returns empty" {
    const allocator = std.testing.allocator;

    // "hello".slice(3, 1) -> ""
    const result1 = try slice(allocator, "hello", 3, 1);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("", result1);

    // "hello".slice(2, 2) -> ""
    const result2 = try slice(allocator, "hello", 2, 2);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("", result2);

    // "hello".slice(10, 15) -> ""
    const result3 = try slice(allocator, "hello", 10, 15);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("", result3);
}

test "slice - emoji (UTF-16 indices)" {
    const allocator = std.testing.allocator;

    // "😀😃".slice(0, 2) -> "😀" (first emoji, 2 UTF-16 units)
    const result1 = try slice(allocator, "😀😃", 0, 2);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("😀", result1);

    // "😀😃".slice(2, 4) -> "😃" (second emoji)
    const result2 = try slice(allocator, "😀😃", 2, 4);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("😃", result2);

    // "a😀b".slice(1, 3) -> "😀"
    const result3 = try slice(allocator, "a😀b", 1, 3);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("😀", result3);
}

test "substring - basic functionality" {
    const allocator = std.testing.allocator;

    // "hello".substring(1, 4) -> "ell"
    const result1 = try substring(allocator, "hello", 1, 4);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("ell", result1);

    // "hello".substring(0, 5) -> "hello"
    const result2 = try substring(allocator, "hello", 0, 5);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello", result2);

    // "hello".substring(2, null) -> "llo"
    const result3 = try substring(allocator, "hello", 2, null);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("llo", result3);
}

test "substring - negative indices treated as 0" {
    const allocator = std.testing.allocator;

    // "hello".substring(-2, null) -> "hello" (negative = 0)
    const result1 = try substring(allocator, "hello", -2, null);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello", result1);

    // "hello".substring(-5, 3) -> "hel"
    const result2 = try substring(allocator, "hello", -5, 3);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hel", result2);
}

test "substring - swaps indices if start > end" {
    const allocator = std.testing.allocator;

    // "hello".substring(3, 1) -> "el" (swapped to 1, 3)
    const result1 = try substring(allocator, "hello", 3, 1);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("el", result1);

    // "hello".substring(4, 2) -> "ll" (swapped to 2, 4)
    const result2 = try substring(allocator, "hello", 4, 2);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("ll", result2);
}

test "substring vs slice - behavior difference" {
    const allocator = std.testing.allocator;

    // slice(-2) vs substring(-2)
    const slice_result = try slice(allocator, "hello", -2, null);
    defer allocator.free(slice_result);
    try std.testing.expectEqualStrings("lo", slice_result);

    const substring_result = try substring(allocator, "hello", -2, null);
    defer allocator.free(substring_result);
    try std.testing.expectEqualStrings("hello", substring_result);

    // slice(3, 1) vs substring(3, 1)
    const slice_result2 = try slice(allocator, "hello", 3, 1);
    defer allocator.free(slice_result2);
    try std.testing.expectEqualStrings("", slice_result2);

    const substring_result2 = try substring(allocator, "hello", 3, 1);
    defer allocator.free(substring_result2);
    try std.testing.expectEqualStrings("el", substring_result2);
}

test "concat - basic functionality" {
    const allocator = std.testing.allocator;

    // "hello".concat("world")
    const result1 = try concat(allocator, "hello", &[_][]const u8{"world"});
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("helloworld", result1);

    // "a".concat("b", "c")
    const result2 = try concat(allocator, "a", &[_][]const u8{ "b", "c" });
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("abc", result2);

    // "".concat("hello")
    const result3 = try concat(allocator, "", &[_][]const u8{"hello"});
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("hello", result3);
}

test "concat - multiple strings" {
    const allocator = std.testing.allocator;

    // "hello".concat(" ", "world", "!")
    const result = try concat(allocator, "hello", &[_][]const u8{ " ", "world", "!" });
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world!", result);
}

test "concat - empty arrays" {
    const allocator = std.testing.allocator;

    // "hello".concat() -> "hello"
    const result = try concat(allocator, "hello", &[_][]const u8{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "concat - emoji" {
    const allocator = std.testing.allocator;

    // "😀".concat("😃")
    const result = try concat(allocator, "😀", &[_][]const u8{"😃"});
    defer allocator.free(result);
    try std.testing.expectEqualStrings("😀😃", result);
}

test "repeat - basic functionality" {
    const allocator = std.testing.allocator;

    // "abc".repeat(0) -> ""
    const result1 = try repeat(allocator, "abc", 0);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("", result1);

    // "abc".repeat(1) -> "abc"
    const result2 = try repeat(allocator, "abc", 1);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("abc", result2);

    // "abc".repeat(3) -> "abcabcabc"
    const result3 = try repeat(allocator, "abc", 3);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("abcabcabc", result3);
}

test "repeat - single character" {
    const allocator = std.testing.allocator;

    // "*".repeat(5) -> "*****"
    const result = try repeat(allocator, "*", 5);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("*****", result);
}

test "repeat - emoji" {
    const allocator = std.testing.allocator;

    // "😀".repeat(3) -> "😀😀😀"
    const result = try repeat(allocator, "😀", 3);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("😀😀😀", result);
}

test "repeat - empty string" {
    const allocator = std.testing.allocator;

    // "".repeat(5) -> ""
    const result = try repeat(allocator, "", 5);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "repeat - negative count returns error" {
    const allocator = std.testing.allocator;

    // "abc".repeat(-1) -> Error
    const result = repeat(allocator, "abc", -1);
    try std.testing.expectError(error.InvalidCount, result);
}
