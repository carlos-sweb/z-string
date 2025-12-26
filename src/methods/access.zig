const std = @import("std");
const utf16 = @import("../core/utf16.zig");
const Allocator = std.mem.Allocator;

/// String.prototype.charAt(index)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.charat
///
/// Returns a new string consisting of the single UTF-16 code unit at the given index.
/// If index is out of bounds, returns an empty string.
///
/// Examples:
///   charAt("hello", 0) -> "h"
///   charAt("hello", 10) -> ""
///   charAt("😀", 0) -> high surrogate as string
///   charAt("😀", 1) -> low surrogate as string
pub fn charAt(allocator: Allocator, str: []const u8, index: isize) ![]u8 {
    // Convert to usize, handling negative indices as out of bounds
    if (index < 0) {
        return allocator.alloc(u8, 0); // Empty string
    }
    const idx: usize = @intCast(index);

    // Get the length in UTF-16 code units
    const len = utf16.lengthUtf16(str);

    // Out of bounds check
    if (idx >= len) {
        return allocator.alloc(u8, 0); // Empty string
    }

    // Convert UTF-16 index to byte index
    const byte_idx = utf16.utf16IndexToByte(str, idx) catch {
        return allocator.alloc(u8, 0);
    };

    if (byte_idx >= str.len) {
        return allocator.alloc(u8, 0);
    }

    // Get the UTF-8 sequence length
    const cp_len = std.unicode.utf8ByteSequenceLength(str[byte_idx]) catch {
        // Invalid UTF-8, return single byte
        const result = try allocator.alloc(u8, 1);
        result[0] = str[byte_idx];
        return result;
    };

    if (byte_idx + cp_len > str.len) {
        // Incomplete sequence
        return allocator.alloc(u8, 0);
    }

    // Return the UTF-8 sequence as a new string
    return allocator.dupe(u8, str[byte_idx .. byte_idx + cp_len]);
}

/// String.prototype.at(index)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.at
///
/// Returns a new string consisting of the single UTF-16 code unit at the given index.
/// Supports negative indexing (counts from the end).
/// If index is out of bounds, returns null.
///
/// Examples:
///   at("hello", 0) -> "h"
///   at("hello", -1) -> "o"
///   at("hello", -5) -> "h"
///   at("hello", 10) -> null
pub fn at(allocator: Allocator, str: []const u8, index: isize) !?[]u8 {
    const len = utf16.lengthUtf16(str);

    // Calculate relative index
    var relative_index: isize = index;

    // Normalize the index
    var k: usize = undefined;
    if (relative_index >= 0) {
        k = @intCast(relative_index);
    } else {
        // Negative index: count from end
        const len_signed: isize = @intCast(len);
        relative_index = len_signed + index;
        if (relative_index < 0) {
            return null; // Out of bounds
        }
        k = @intCast(relative_index);
    }

    // Out of bounds check
    if (k >= len) {
        return null;
    }

    // Convert UTF-16 index to byte index
    const byte_idx = utf16.utf16IndexToByte(str, k) catch {
        return null;
    };

    if (byte_idx >= str.len) {
        return null;
    }

    // Get the UTF-8 sequence length
    const cp_len = std.unicode.utf8ByteSequenceLength(str[byte_idx]) catch {
        // Invalid UTF-8, return single byte
        const result = try allocator.alloc(u8, 1);
        result[0] = str[byte_idx];
        return result;
    };

    if (byte_idx + cp_len > str.len) {
        return null;
    }

    // Return the UTF-8 sequence as a new string
    return try allocator.dupe(u8, str[byte_idx .. byte_idx + cp_len]);
}

/// String.prototype.charCodeAt(index)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.charcodeat
///
/// Returns the UTF-16 code unit at the given index.
/// If index is out of bounds, returns null (represents NaN in JS).
///
/// For characters in the BMP (U+0000 to U+FFFF), this is the code point.
/// For characters above BMP, this returns either the high or low surrogate.
///
/// Examples:
///   charCodeAt("ABC", 0) -> 65 (0x41)
///   charCodeAt("😀", 0) -> 55357 (0xD83D, high surrogate)
///   charCodeAt("😀", 1) -> 56832 (0xDE00, low surrogate)
///   charCodeAt("hello", 10) -> null
pub fn charCodeAt(str: []const u8, index: isize) ?u16 {
    // Negative indices are out of bounds
    if (index < 0) {
        return null;
    }
    const idx: usize = @intCast(index);

    // Get the length in UTF-16 code units
    const len = utf16.lengthUtf16(str);

    // Out of bounds check
    if (idx >= len) {
        return null;
    }

    // Get the UTF-16 code unit at this index
    return utf16.codeUnitAt(str, idx) catch null;
}

/// String.prototype.codePointAt(index)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.codepointat
///
/// Returns the Unicode code point at the given index.
/// Unlike charCodeAt, this correctly handles surrogate pairs.
///
/// If the code unit at index is a high surrogate and the next is a low surrogate,
/// returns the full code point. Otherwise returns the code unit value.
///
/// Examples:
///   codePointAt("ABC", 0) -> 65 (0x41)
///   codePointAt("😀", 0) -> 128512 (0x1F600, full emoji code point)
///   codePointAt("😀", 1) -> 56832 (0xDE00, low surrogate - not a pair start)
///   codePointAt("hello", 10) -> null
pub fn codePointAt(str: []const u8, index: isize) ?u21 {
    // Negative indices are out of bounds
    if (index < 0) {
        return null;
    }
    const idx: usize = @intCast(index);

    // Get the length in UTF-16 code units
    const len = utf16.lengthUtf16(str);

    // Out of bounds check
    if (idx >= len) {
        return null;
    }

    // Convert UTF-16 index to byte index
    const byte_idx = utf16.utf16IndexToByte(str, idx) catch {
        return null;
    };

    if (byte_idx >= str.len) {
        return null;
    }

    // Get the UTF-8 sequence length
    const cp_len = std.unicode.utf8ByteSequenceLength(str[byte_idx]) catch {
        // Invalid UTF-8
        return null;
    };

    if (byte_idx + cp_len > str.len) {
        // Incomplete sequence
        return null;
    }

    // Decode the UTF-8 sequence to get the full code point
    const codepoint = std.unicode.utf8Decode(str[byte_idx .. byte_idx + cp_len]) catch {
        return null;
    };

    return codepoint;
}

// ============================================================================
// Tests
// ============================================================================

test "charAt - basic ASCII" {
    const allocator = std.testing.allocator;

    const result1 = try charAt(allocator, "hello", 0);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("h", result1);

    const result2 = try charAt(allocator, "hello", 4);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("o", result2);

    const result3 = try charAt(allocator, "ABC", 1);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("B", result3);
}

test "charAt - out of bounds" {
    const allocator = std.testing.allocator;

    // Beyond string length
    const result1 = try charAt(allocator, "hello", 10);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("", result1);

    // Negative index
    const result2 = try charAt(allocator, "hello", -1);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("", result2);

    // Empty string
    const result3 = try charAt(allocator, "", 0);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("", result3);
}

test "charAt - Unicode BMP" {
    const allocator = std.testing.allocator;

    const result1 = try charAt(allocator, "café", 3);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("é", result1);

    const result2 = try charAt(allocator, "你好", 0);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("你", result2);

    const result3 = try charAt(allocator, "你好", 1);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("好", result3);
}

test "charAt - emoji (surrogate pair)" {
    const allocator = std.testing.allocator;

    // 😀 is U+1F600, which is a surrogate pair in UTF-16
    // In UTF-8 it's 4 bytes: F0 9F 98 80
    // charAt(0) should return the entire emoji as UTF-8
    const result1 = try charAt(allocator, "😀", 0);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("😀", result1);

    // charAt(1) also returns the same emoji (low surrogate position)
    const result2 = try charAt(allocator, "😀", 1);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("😀", result2);

    // Out of bounds (emoji has length 2 in UTF-16)
    const result3 = try charAt(allocator, "😀", 2);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("", result3);
}

test "at - basic ASCII" {
    const allocator = std.testing.allocator;

    const result1 = try at(allocator, "hello", 0);
    try std.testing.expect(result1 != null);
    defer allocator.free(result1.?);
    try std.testing.expectEqualStrings("h", result1.?);

    const result2 = try at(allocator, "hello", 4);
    try std.testing.expect(result2 != null);
    defer allocator.free(result2.?);
    try std.testing.expectEqualStrings("o", result2.?);
}

test "at - negative indices" {
    const allocator = std.testing.allocator;

    // -1 should be last character
    const result1 = try at(allocator, "hello", -1);
    try std.testing.expect(result1 != null);
    defer allocator.free(result1.?);
    try std.testing.expectEqualStrings("o", result1.?);

    // -5 should be first character
    const result2 = try at(allocator, "hello", -5);
    try std.testing.expect(result2 != null);
    defer allocator.free(result2.?);
    try std.testing.expectEqualStrings("h", result2.?);

    // -2 should be second to last
    const result3 = try at(allocator, "hello", -2);
    try std.testing.expect(result3 != null);
    defer allocator.free(result3.?);
    try std.testing.expectEqualStrings("l", result3.?);
}

test "at - out of bounds returns null" {
    const allocator = std.testing.allocator;

    // Beyond string length
    const result1 = try at(allocator, "hello", 10);
    try std.testing.expect(result1 == null);

    // Negative index too large
    const result2 = try at(allocator, "hello", -10);
    try std.testing.expect(result2 == null);

    // Empty string
    const result3 = try at(allocator, "", 0);
    try std.testing.expect(result3 == null);
}

test "at - emoji with negative index" {
    const allocator = std.testing.allocator;

    // "😀" has length 2 in UTF-16
    // at(-1) should return the emoji (accessing the low surrogate position)
    const result1 = try at(allocator, "😀", -1);
    try std.testing.expect(result1 != null);
    defer allocator.free(result1.?);
    try std.testing.expectEqualStrings("😀", result1.?);

    // at(-2) should return the emoji (accessing the high surrogate position)
    const result2 = try at(allocator, "😀", -2);
    try std.testing.expect(result2 != null);
    defer allocator.free(result2.?);
    try std.testing.expectEqualStrings("😀", result2.?);

    // at(-3) is out of bounds
    const result3 = try at(allocator, "😀", -3);
    try std.testing.expect(result3 == null);
}

test "charCodeAt - basic ASCII" {
    try std.testing.expectEqual(@as(?u16, 0x0041), charCodeAt("ABC", 0)); // 'A'
    try std.testing.expectEqual(@as(?u16, 0x0042), charCodeAt("ABC", 1)); // 'B'
    try std.testing.expectEqual(@as(?u16, 0x0043), charCodeAt("ABC", 2)); // 'C'
    try std.testing.expectEqual(@as(?u16, 0x0068), charCodeAt("hello", 0)); // 'h'
}

test "charCodeAt - out of bounds" {
    try std.testing.expectEqual(@as(?u16, null), charCodeAt("hello", 10));
    try std.testing.expectEqual(@as(?u16, null), charCodeAt("hello", -1));
    try std.testing.expectEqual(@as(?u16, null), charCodeAt("", 0));
}

test "charCodeAt - Unicode BMP" {
    try std.testing.expectEqual(@as(?u16, 0x00E9), charCodeAt("é", 0)); // é
    try std.testing.expectEqual(@as(?u16, 0x4F60), charCodeAt("你", 0)); // 你
}

test "charCodeAt - emoji (surrogate pair)" {
    // 😀 is U+1F600
    // High surrogate: 0xD83D
    // Low surrogate: 0xDE00
    try std.testing.expectEqual(@as(?u16, 0xD83D), charCodeAt("😀", 0));
    try std.testing.expectEqual(@as(?u16, 0xDE00), charCodeAt("😀", 1));
    try std.testing.expectEqual(@as(?u16, null), charCodeAt("😀", 2));
}

test "codePointAt - basic ASCII" {
    try std.testing.expectEqual(@as(?u21, 0x0041), codePointAt("ABC", 0)); // 'A'
    try std.testing.expectEqual(@as(?u21, 0x0042), codePointAt("ABC", 1)); // 'B'
    try std.testing.expectEqual(@as(?u21, 0x0043), codePointAt("ABC", 2)); // 'C'
}

test "codePointAt - out of bounds" {
    try std.testing.expectEqual(@as(?u21, null), codePointAt("hello", 10));
    try std.testing.expectEqual(@as(?u21, null), codePointAt("hello", -1));
    try std.testing.expectEqual(@as(?u21, null), codePointAt("", 0));
}

test "codePointAt - Unicode BMP" {
    try std.testing.expectEqual(@as(?u21, 0x00E9), codePointAt("é", 0)); // é
    try std.testing.expectEqual(@as(?u21, 0x4F60), codePointAt("你", 0)); // 你
}

test "codePointAt - emoji (full code point)" {
    // 😀 is U+1F600
    // At index 0 (high surrogate position), should return full code point
    try std.testing.expectEqual(@as(?u21, 0x1F600), codePointAt("😀", 0));

    // At index 1 (low surrogate position), should still return full code point
    // because both indices point to the same UTF-8 sequence
    try std.testing.expectEqual(@as(?u21, 0x1F600), codePointAt("😀", 1));

    // Out of bounds
    try std.testing.expectEqual(@as(?u21, null), codePointAt("😀", 2));
}

test "codePointAt - mixed content" {
    const str = "a😀b";
    // 'a' at index 0
    try std.testing.expectEqual(@as(?u21, 0x0061), codePointAt(str, 0));
    // emoji at indices 1-2
    try std.testing.expectEqual(@as(?u21, 0x1F600), codePointAt(str, 1));
    try std.testing.expectEqual(@as(?u21, 0x1F600), codePointAt(str, 2));
    // 'b' at index 3
    try std.testing.expectEqual(@as(?u21, 0x0062), codePointAt(str, 3));
}
