const std = @import("std");
const utf16 = @import("../core/utf16.zig");

/// String.prototype.indexOf(searchString, position)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.indexof
///
/// Returns the index of the first occurrence of searchString within this string,
/// starting at position. Returns -1 if not found.
///
/// Note: All indices are in UTF-16 code units (ECMAScript compatible).
///
/// Examples:
///   indexOf("hello world", "o", 0) -> 4
///   indexOf("hello world", "o", 5) -> 7
///   indexOf("hello world", "x", 0) -> -1
///   indexOf("😀😃", "😃", 0) -> 2 (emoji is 2 UTF-16 code units)
pub fn indexOf(str: []const u8, search: []const u8, position: ?isize) isize {
    // Handle empty search string - spec says return position (or 0)
    if (search.len == 0) {
        if (position) |pos| {
            if (pos < 0) return 0;
            const len = utf16.lengthUtf16(str);
            return @min(pos, @as(isize, @intCast(len)));
        }
        return 0;
    }

    const len = utf16.lengthUtf16(str);

    // Normalize position
    var start_pos: usize = 0;
    if (position) |pos| {
        if (pos < 0) {
            start_pos = 0;
        } else if (pos >= @as(isize, @intCast(len))) {
            return -1; // Start position beyond string length
        } else {
            start_pos = @intCast(pos);
        }
    }

    // Convert UTF-16 position to byte index
    const start_byte = utf16.utf16IndexToByte(str, start_pos) catch return -1;

    // Search for the substring using byte indices
    if (std.mem.indexOf(u8, str[start_byte..], search)) |byte_offset| {
        // Found! Convert byte offset back to UTF-16 index
        const absolute_byte = start_byte + byte_offset;
        const utf16_index = utf16.byteIndexToUtf16(str, absolute_byte) catch return -1;
        return @intCast(utf16_index);
    }

    return -1; // Not found
}

/// String.prototype.lastIndexOf(searchString, position)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.lastindexof
///
/// Returns the index of the last occurrence of searchString within this string,
/// searching backwards from position. Returns -1 if not found.
///
/// Examples:
///   lastIndexOf("hello world hello", "hello", null) -> 12
///   lastIndexOf("hello world hello", "hello", 10) -> 0
///   lastIndexOf("hello world hello", "x", null) -> -1
pub fn lastIndexOf(str: []const u8, search: []const u8, position: ?isize) isize {
    const len = utf16.lengthUtf16(str);

    // Handle empty search string
    if (search.len == 0) {
        if (position) |pos| {
            if (pos < 0) return 0;
            return @min(pos, @as(isize, @intCast(len)));
        }
        return @intCast(len);
    }

    if (len == 0) return -1;

    // Normalize position (default is end of string)
    var search_pos: usize = len;
    if (position) |pos| {
        if (pos < 0) {
            return -1;
        } else if (pos < @as(isize, @intCast(len))) {
            search_pos = @intCast(pos);
        }
    }

    // Search from the end backwards
    // We'll iterate through all occurrences and keep the last one before position
    var last_found: isize = -1;
    var current_byte: usize = 0;

    while (current_byte < str.len) {
        if (std.mem.indexOf(u8, str[current_byte..], search)) |byte_offset| {
            const absolute_byte = current_byte + byte_offset;
            const utf16_index = utf16.byteIndexToUtf16(str, absolute_byte) catch break;

            // Check if this occurrence is within our search range
            if (utf16_index <= search_pos) {
                last_found = @intCast(utf16_index);
                // Continue searching after this occurrence
                current_byte = absolute_byte + 1;
            } else {
                // Beyond our search range, stop
                break;
            }
        } else {
            // No more occurrences
            break;
        }
    }

    return last_found;
}

/// String.prototype.includes(searchString, position)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.includes
///
/// Determines whether searchString appears within this string,
/// starting the search at position.
///
/// Examples:
///   includes("hello world", "world", 0) -> true
///   includes("hello world", "world", 7) -> false
///   includes("hello world", "x", 0) -> false
pub fn includes(str: []const u8, search: []const u8, position: ?isize) bool {
    return indexOf(str, search, position) != -1;
}

/// String.prototype.startsWith(searchString, position)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.startswith
///
/// Determines whether this string begins with searchString,
/// optionally starting at position.
///
/// Examples:
///   startsWith("hello world", "hello", null) -> true
///   startsWith("hello world", "world", 6) -> true
///   startsWith("hello world", "hello", 1) -> false
pub fn startsWith(str: []const u8, search: []const u8, position: ?isize) bool {
    const len = utf16.lengthUtf16(str);

    // Normalize position
    var start_pos: usize = 0;
    if (position) |pos| {
        if (pos < 0) {
            start_pos = 0;
        } else if (pos >= @as(isize, @intCast(len))) {
            // Position at or beyond end
            return search.len == 0;
        } else {
            start_pos = @intCast(pos);
        }
    }

    // Convert UTF-16 position to byte index
    const start_byte = utf16.utf16IndexToByte(str, start_pos) catch return false;

    // Check if the substring at start_byte matches search
    if (start_byte + search.len > str.len) {
        return false; // Not enough bytes remaining
    }

    return std.mem.startsWith(u8, str[start_byte..], search);
}

/// String.prototype.endsWith(searchString, endPosition)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.endswith
///
/// Determines whether this string ends with searchString,
/// treating the string as if it were only endPosition characters long.
///
/// Examples:
///   endsWith("hello world", "world", null) -> true
///   endsWith("hello world", "hello", 5) -> true
///   endsWith("hello world", "world", 5) -> false
pub fn endsWith(str: []const u8, search: []const u8, endPosition: ?isize) bool {
    // Handle empty search string - always returns true
    if (search.len == 0) {
        return true;
    }

    const len = utf16.lengthUtf16(str);

    // Normalize end position (default is full string length)
    var end_pos: usize = len;
    if (endPosition) |pos| {
        if (pos < 0) {
            end_pos = 0;
        } else if (pos < @as(isize, @intCast(len))) {
            end_pos = @intCast(pos);
        }
    }

    // Get the length of the search string in UTF-16 code units
    const search_len_utf16 = utf16.lengthUtf16(search);

    // Check if search string is longer than the position we're checking
    if (search_len_utf16 > end_pos) {
        return false;
    }

    // Calculate the starting position for comparison (in UTF-16)
    const compare_start_utf16 = end_pos - search_len_utf16;

    // Convert to byte indices
    const compare_start_byte = utf16.utf16IndexToByte(str, compare_start_utf16) catch return false;
    const end_byte = utf16.utf16IndexToByte(str, end_pos) catch return false;

    // Check if the slice matches
    if (compare_start_byte >= str.len or end_byte > str.len) {
        return false;
    }

    const slice_to_check = str[compare_start_byte..end_byte];
    return std.mem.eql(u8, slice_to_check, search);
}

// ============================================================================
// Tests
// ============================================================================

test "indexOf - basic functionality" {
    try std.testing.expectEqual(@as(isize, 0), indexOf("hello", "hello", null));
    try std.testing.expectEqual(@as(isize, 0), indexOf("hello", "h", null));
    try std.testing.expectEqual(@as(isize, 4), indexOf("hello", "o", null));
    try std.testing.expectEqual(@as(isize, 1), indexOf("hello", "ell", null));
}

test "indexOf - with position" {
    try std.testing.expectEqual(@as(isize, 4), indexOf("hello world", "o", 0));
    try std.testing.expectEqual(@as(isize, 7), indexOf("hello world", "o", 5));
    try std.testing.expectEqual(@as(isize, 7), indexOf("hello world", "o", 7));
    try std.testing.expectEqual(@as(isize, -1), indexOf("hello world", "o", 8));
}

test "indexOf - not found" {
    try std.testing.expectEqual(@as(isize, -1), indexOf("hello", "x", null));
    try std.testing.expectEqual(@as(isize, -1), indexOf("hello", "world", null));
    try std.testing.expectEqual(@as(isize, -1), indexOf("hello", "hello!", null));
}

test "indexOf - empty search string" {
    try std.testing.expectEqual(@as(isize, 0), indexOf("hello", "", null));
    try std.testing.expectEqual(@as(isize, 3), indexOf("hello", "", 3));
    try std.testing.expectEqual(@as(isize, 5), indexOf("hello", "", 10)); // Clamped to length
}

test "indexOf - negative position" {
    // Negative position is treated as 0
    try std.testing.expectEqual(@as(isize, 0), indexOf("hello", "h", -1));
    try std.testing.expectEqual(@as(isize, 4), indexOf("hello", "o", -5));
}

test "indexOf - emoji (UTF-16 indices)" {
    // "😀" is 2 UTF-16 code units, 4 UTF-8 bytes
    try std.testing.expectEqual(@as(isize, 0), indexOf("😀", "😀", null));
    try std.testing.expectEqual(@as(isize, 2), indexOf("😀😃", "😃", null));
    try std.testing.expectEqual(@as(isize, -1), indexOf("😀", "😃", null));
}

test "indexOf - mixed ASCII and emoji" {
    const str = "hello😀world";
    // h=0, e=1, l=2, l=3, o=4, 😀=5-6, w=7, o=8, r=9, l=10, d=11
    try std.testing.expectEqual(@as(isize, 0), indexOf(str, "hello", null));
    try std.testing.expectEqual(@as(isize, 5), indexOf(str, "😀", null));
    try std.testing.expectEqual(@as(isize, 7), indexOf(str, "world", null));
}

test "lastIndexOf - basic functionality" {
    try std.testing.expectEqual(@as(isize, 0), lastIndexOf("hello", "hello", null));
    try std.testing.expectEqual(@as(isize, 0), lastIndexOf("hello", "h", null));
    try std.testing.expectEqual(@as(isize, 4), lastIndexOf("hello", "o", null));
}

test "lastIndexOf - multiple occurrences" {
    try std.testing.expectEqual(@as(isize, 12), lastIndexOf("hello world hello", "hello", null));
    // "hello world hello" has 'o' at positions 4, 7, 16 - last one is 16
    try std.testing.expectEqual(@as(isize, 16), lastIndexOf("hello world hello", "o", null));
}

test "lastIndexOf - with position" {
    try std.testing.expectEqual(@as(isize, 0), lastIndexOf("hello world hello", "hello", 10));
    try std.testing.expectEqual(@as(isize, 4), lastIndexOf("hello world hello", "o", 6));
    try std.testing.expectEqual(@as(isize, 7), lastIndexOf("hello world hello", "o", 7));
}

test "lastIndexOf - not found" {
    try std.testing.expectEqual(@as(isize, -1), lastIndexOf("hello", "x", null));
    try std.testing.expectEqual(@as(isize, -1), lastIndexOf("hello", "world", null));
}

test "lastIndexOf - empty search string" {
    try std.testing.expectEqual(@as(isize, 5), lastIndexOf("hello", "", null));
    try std.testing.expectEqual(@as(isize, 3), lastIndexOf("hello", "", 3));
}

test "includes - basic functionality" {
    try std.testing.expect(includes("hello world", "world", null));
    try std.testing.expect(includes("hello world", "hello", null));
    try std.testing.expect(includes("hello world", "o", null));
    try std.testing.expect(!includes("hello world", "x", null));
}

test "includes - with position" {
    try std.testing.expect(includes("hello world", "world", 0));
    try std.testing.expect(!includes("hello world", "hello", 1));
    try std.testing.expect(includes("hello world", "world", 6));
}

test "includes - empty string" {
    try std.testing.expect(includes("hello", "", null));
    try std.testing.expect(includes("", "", null));
}

test "startsWith - basic functionality" {
    try std.testing.expect(startsWith("hello world", "hello", null));
    try std.testing.expect(!startsWith("hello world", "world", null));
    try std.testing.expect(startsWith("hello", "h", null));
}

test "startsWith - with position" {
    try std.testing.expect(startsWith("hello world", "world", 6));
    try std.testing.expect(!startsWith("hello world", "hello", 1));
    try std.testing.expect(startsWith("hello world", "o", 4));
}

test "startsWith - empty search string" {
    try std.testing.expect(startsWith("hello", "", null));
    try std.testing.expect(startsWith("hello", "", 3));
}

test "startsWith - emoji" {
    try std.testing.expect(startsWith("😀hello", "😀", null));
    try std.testing.expect(!startsWith("😀hello", "hello", null));
    try std.testing.expect(startsWith("😀hello", "hello", 2)); // After emoji (2 UTF-16 units)
}

test "endsWith - basic functionality" {
    try std.testing.expect(endsWith("hello world", "world", null));
    try std.testing.expect(!endsWith("hello world", "hello", null));
    try std.testing.expect(endsWith("hello", "o", null));
    try std.testing.expect(endsWith("hello", "lo", null));
}

test "endsWith - with end position" {
    try std.testing.expect(endsWith("hello world", "hello", 5));
    try std.testing.expect(!endsWith("hello world", "world", 5));
    try std.testing.expect(endsWith("hello world", "o", 5));
}

test "endsWith - empty search string" {
    try std.testing.expect(endsWith("hello", "", null));
    try std.testing.expect(endsWith("hello", "", 3));
}

test "endsWith - emoji" {
    try std.testing.expect(endsWith("hello😀", "😀", null));
    try std.testing.expect(!endsWith("hello😀", "hello", null));
    try std.testing.expect(endsWith("hello😀", "o😀", null));
}

test "endsWith - exact length" {
    try std.testing.expect(endsWith("hello", "hello", null));
    try std.testing.expect(endsWith("hello", "hello", 5));
}
