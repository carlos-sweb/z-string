const units = @import("../core/units.zig");
const std = @import("std");
const utf16 = @import("../core/utf16.zig");

/// String.prototype.indexOf(searchString, position)
/// Spec: https://tc39.es/ecma262/#sec-string.prototype.indexof
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
    const ascii = units.isAscii(str);
    const len = if (ascii) str.len else utf16.lengthUtf16(str);
    const start: usize = if (position) |p| @intCast(@max(0, @min(p, @as(isize, @intCast(len))))) else 0;
    if (search.len == 0) return @intCast(start);
    if (ascii) {
        return if (std.mem.indexOfPos(u8, str, start, search)) |i| @intCast(i) else -1;
    }
    if (std.unicode.utf8ValidateSlice(str) and std.unicode.utf8ValidateSlice(search)) {
        const boundary = utf16.utf16IndexToBytePos(str, start) catch return -1;
        // A complete code point cannot start at the low half of another pair.
        const byte_start = boundary.byte_index + (if (boundary.is_low_surrogate) @as(usize, 4) else 0);
        const found = std.mem.indexOfPos(u8, str, byte_start, search) orelse return -1;
        return @intCast(utf16.byteIndexToUtf16(str, found) catch return -1);
    }
    var cursor: units.Cursor = .{ .data = str };
    cursor.skip(start);
    var i = start;
    while (i < len) : (i += 1) {
        if (matches(cursor, search)) return @intCast(i);
        _ = cursor.next();
    }
    return -1;
}

/// String.prototype.lastIndexOf(searchString, position)
/// Spec: https://tc39.es/ecma262/#sec-string.prototype.lastindexof
///
/// Returns the index of the last occurrence of searchString within this string,
/// searching backwards from position. Returns -1 if not found.
///
/// Examples:
///   lastIndexOf("hello world hello", "hello", null) -> 12
///   lastIndexOf("hello world hello", "hello", 10) -> 0
///   lastIndexOf("hello world hello", "x", null) -> -1
pub fn lastIndexOf(str: []const u8, search: []const u8, position: ?isize) isize {
    const ascii = units.isAscii(str);
    const len = if (ascii) str.len else utf16.lengthUtf16(str);
    const stop: usize = if (position) |p| @intCast(@max(0, @min(p, @as(isize, @intCast(len))))) else len;
    if (search.len == 0) return @intCast(stop);
    var found: isize = -1;
    if (ascii) {
        var pos: usize = 0;
        while (std.mem.indexOfPos(u8, str, pos, search)) |i| {
            if (i > stop) break;
            found = @intCast(i);
            pos = i + 1;
        }
        return found;
    }
    var cursor: units.Cursor = .{ .data = str };
    var i: usize = 0;
    while (i <= stop and i < len) : (i += 1) {
        if (matches(cursor, search)) found = @intCast(i);
        _ = cursor.next();
    }
    return found;
}

/// String.prototype.includes(searchString, position)
/// Spec: https://tc39.es/ecma262/#sec-string.prototype.includes
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
/// Spec: https://tc39.es/ecma262/#sec-string.prototype.startswith
///
/// Determines whether this string begins with searchString,
/// optionally starting at position.
///
/// Examples:
///   startsWith("hello world", "hello", null) -> true
///   startsWith("hello world", "world", 6) -> true
///   startsWith("hello world", "hello", 1) -> false
pub fn startsWith(str: []const u8, search: []const u8, position: ?isize) bool {
    const ascii = units.isAscii(str);
    const len = if (ascii) str.len else utf16.lengthUtf16(str);
    const start: usize = if (position) |p| @intCast(@max(0, @min(p, @as(isize, @intCast(len))))) else 0;
    if (ascii) return std.mem.startsWith(u8, str[start..], search);
    var cursor: units.Cursor = .{ .data = str };
    cursor.skip(start);
    return matches(cursor, search);
}

/// String.prototype.endsWith(searchString, endPosition)
/// Spec: https://tc39.es/ecma262/#sec-string.prototype.endswith
///
/// Determines whether this string ends with searchString,
/// treating the string as if it were only endPosition characters long.
///
/// Examples:
///   endsWith("hello world", "world", null) -> true
///   endsWith("hello world", "hello", 5) -> true
///   endsWith("hello world", "world", 5) -> false
pub fn endsWith(str: []const u8, search: []const u8, endPosition: ?isize) bool {
    const ascii = units.isAscii(str);
    const len = if (ascii) str.len else utf16.lengthUtf16(str);
    const end: usize = if (endPosition) |p| @intCast(@max(0, @min(p, @as(isize, @intCast(len))))) else len;
    const n = if (ascii) search.len else utf16.lengthUtf16(search);
    if (n > end) return false;
    if (ascii) return std.mem.endsWith(u8, str[0..end], search);
    var cursor: units.Cursor = .{ .data = str };
    cursor.skip(end - n);
    return matches(cursor, search);
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

const matches = units.matches;
