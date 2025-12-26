const std = @import("std");
const utf16 = @import("../core/utf16.zig");
const Allocator = std.mem.Allocator;

/// String.prototype.padStart(targetLength, padString)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.padstart
///
/// Pads the current string with another string (multiple times, if needed)
/// until the resulting string reaches the given length.
/// The padding is applied from the start of the current string.
///
/// Examples:
///   padStart("5", 3, "0") -> "005"
///   padStart("abc", 10, null) -> "       abc" (default space)
///   padStart("abc", 6, "123456") -> "123abc"
///   padStart("abc", 2, "0") -> "abc" (no change if already long enough)
pub fn padStart(allocator: Allocator, str: []const u8, targetLength: isize, padString: ?[]const u8) ![]u8 {
    if (targetLength < 0) {
        // Negative target length, return copy of original
        return allocator.dupe(u8, str);
    }

    const target_len: usize = @intCast(targetLength);
    const str_len = utf16.lengthUtf16(str);

    // If already at or beyond target length, return copy
    if (str_len >= target_len) {
        return allocator.dupe(u8, str);
    }

    // Determine padding string (default is space)
    const pad = padString orelse " ";

    // Empty pad string means no padding
    if (pad.len == 0) {
        return allocator.dupe(u8, str);
    }

    const pad_len_utf16 = utf16.lengthUtf16(pad);
    if (pad_len_utf16 == 0) {
        return allocator.dupe(u8, str);
    }

    // Calculate how many UTF-16 code units we need to add
    const needed_len = target_len - str_len;

    // Calculate how many times to repeat the pad string
    const full_repeats = needed_len / pad_len_utf16;
    const partial_len = needed_len % pad_len_utf16;

    // Calculate total byte size
    const total_byte_len = (full_repeats * pad.len) + str.len;

    // Add bytes for partial padding if needed
    var result_len = total_byte_len;
    if (partial_len > 0) {
        // Convert partial UTF-16 length to bytes
        const partial_byte_len = utf16.utf16IndexToByte(pad, partial_len) catch pad.len;
        result_len += partial_byte_len;
    }

    // Allocate result buffer
    var result = try allocator.alloc(u8, result_len);
    errdefer allocator.free(result);

    var pos: usize = 0;

    // Add full repetitions of pad string
    var i: usize = 0;
    while (i < full_repeats) : (i += 1) {
        @memcpy(result[pos .. pos + pad.len], pad);
        pos += pad.len;
    }

    // Add partial pad string if needed
    if (partial_len > 0) {
        const partial_byte_len = utf16.utf16IndexToByte(pad, partial_len) catch pad.len;
        @memcpy(result[pos .. pos + partial_byte_len], pad[0..partial_byte_len]);
        pos += partial_byte_len;
    }

    // Add original string
    @memcpy(result[pos .. pos + str.len], str);

    return result;
}

/// String.prototype.padEnd(targetLength, padString)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.padend
///
/// Pads the current string with another string (multiple times, if needed)
/// until the resulting string reaches the given length.
/// The padding is applied from the end of the current string.
///
/// Examples:
///   padEnd("5", 3, "0") -> "500"
///   padEnd("abc", 10, null) -> "abc       " (default space)
///   padEnd("abc", 6, "123456") -> "abc123"
///   padEnd("abc", 2, "0") -> "abc" (no change if already long enough)
pub fn padEnd(allocator: Allocator, str: []const u8, targetLength: isize, padString: ?[]const u8) ![]u8 {
    if (targetLength < 0) {
        return allocator.dupe(u8, str);
    }

    const target_len: usize = @intCast(targetLength);
    const str_len = utf16.lengthUtf16(str);

    // If already at or beyond target length, return copy
    if (str_len >= target_len) {
        return allocator.dupe(u8, str);
    }

    // Determine padding string (default is space)
    const pad = padString orelse " ";

    if (pad.len == 0) {
        return allocator.dupe(u8, str);
    }

    const pad_len_utf16 = utf16.lengthUtf16(pad);
    if (pad_len_utf16 == 0) {
        return allocator.dupe(u8, str);
    }

    // Calculate how many UTF-16 code units we need to add
    const needed_len = target_len - str_len;

    // Calculate how many times to repeat the pad string
    const full_repeats = needed_len / pad_len_utf16;
    const partial_len = needed_len % pad_len_utf16;

    // Calculate total byte size
    var result_len = str.len + (full_repeats * pad.len);
    if (partial_len > 0) {
        const partial_byte_len = utf16.utf16IndexToByte(pad, partial_len) catch pad.len;
        result_len += partial_byte_len;
    }

    // Allocate result buffer
    var result = try allocator.alloc(u8, result_len);
    errdefer allocator.free(result);

    // Add original string first
    @memcpy(result[0..str.len], str);
    var pos: usize = str.len;

    // Add full repetitions of pad string
    var i: usize = 0;
    while (i < full_repeats) : (i += 1) {
        @memcpy(result[pos .. pos + pad.len], pad);
        pos += pad.len;
    }

    // Add partial pad string if needed
    if (partial_len > 0) {
        const partial_byte_len = utf16.utf16IndexToByte(pad, partial_len) catch pad.len;
        @memcpy(result[pos .. pos + partial_byte_len], pad[0..partial_byte_len]);
    }

    return result;
}

// ============================================================================
// Tests
// ============================================================================

test "padStart - basic functionality" {
    const allocator = std.testing.allocator;

    // "5".padStart(3, "0") -> "005"
    const result1 = try padStart(allocator, "5", 3, "0");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("005", result1);

    // "abc".padStart(10) -> "       abc" (default space)
    const result2 = try padStart(allocator, "abc", 10, null);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("       abc", result2);

    // "abc".padStart(6, "123") -> "123abc"
    const result3 = try padStart(allocator, "abc", 6, "123");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("123abc", result3);
}

test "padStart - already long enough" {
    const allocator = std.testing.allocator;

    // "abc".padStart(2, "0") -> "abc"
    const result1 = try padStart(allocator, "abc", 2, "0");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("abc", result1);

    // "abc".padStart(3, "0") -> "abc"
    const result2 = try padStart(allocator, "abc", 3, "0");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("abc", result2);
}

test "padStart - multi-character pad" {
    const allocator = std.testing.allocator;

    // "abc".padStart(10, "foo") -> "foofoofabc"
    const result = try padStart(allocator, "abc", 10, "foo");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("foofoofabc", result);
}

test "padStart - partial pad" {
    const allocator = std.testing.allocator;

    // "abc".padStart(5, "12") -> "12abc" (partial "12")
    const result = try padStart(allocator, "abc", 5, "12");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("12abc", result);
}

test "padStart - empty string" {
    const allocator = std.testing.allocator;

    // "".padStart(3, "x") -> "xxx"
    const result = try padStart(allocator, "", 3, "x");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("xxx", result);
}

test "padEnd - basic functionality" {
    const allocator = std.testing.allocator;

    // "5".padEnd(3, "0") -> "500"
    const result1 = try padEnd(allocator, "5", 3, "0");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("500", result1);

    // "abc".padEnd(10) -> "abc       " (default space)
    const result2 = try padEnd(allocator, "abc", 10, null);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("abc       ", result2);

    // "abc".padEnd(6, "123") -> "abc123"
    const result3 = try padEnd(allocator, "abc", 6, "123");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("abc123", result3);
}

test "padEnd - already long enough" {
    const allocator = std.testing.allocator;

    // "abc".padEnd(2, "0") -> "abc"
    const result = try padEnd(allocator, "abc", 2, "0");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abc", result);
}

test "padEnd - multi-character pad" {
    const allocator = std.testing.allocator;

    // "abc".padEnd(10, "foo") -> "abcfoofoot"
    const result = try padEnd(allocator, "abc", 10, "foo");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abcfoofoof", result);
}

test "padEnd - partial pad" {
    const allocator = std.testing.allocator;

    // "abc".padEnd(5, "12") -> "abc12"
    const result = try padEnd(allocator, "abc", 5, "12");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abc12", result);
}

test "padEnd - empty string" {
    const allocator = std.testing.allocator;

    // "".padEnd(3, "x") -> "xxx"
    const result = try padEnd(allocator, "", 3, "x");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("xxx", result);
}
