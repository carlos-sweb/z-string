const std = @import("std");

/// Errors that can occur during UTF-16 operations
pub const Utf16Error = error{
    InvalidUtf8,
    InvalidUtf16,
    IndexOutOfBounds,
    InvalidCodePoint,
};

/// Returns the length of a UTF-8 string in UTF-16 code units
/// This matches JavaScript's String.length behavior
///
/// Examples:
///   "hello" -> 5 code units
///   "café" -> 4 code units
///   "😀" -> 2 code units (surrogate pair)
///   "你好" -> 2 code units
pub fn lengthUtf16(str: []const u8) usize {
    var count: usize = 0;
    var i: usize = 0;

    while (i < str.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(str[i]) catch {
            // Invalid UTF-8, count as 1 and skip
            i += 1;
            count += 1;
            continue;
        };

        if (i + cp_len > str.len) {
            // Incomplete sequence at end
            count += 1;
            break;
        }

        const codepoint = std.unicode.utf8Decode(str[i .. i + cp_len]) catch {
            // Invalid UTF-8 sequence, count as 1
            i += 1;
            count += 1;
            continue;
        };

        // Code points in BMP (0x0000 to 0xFFFF) = 1 UTF-16 code unit
        // Code points above BMP (0x10000 to 0x10FFFF) = 2 UTF-16 code units (surrogate pair)
        if (codepoint <= 0xFFFF) {
            count += 1;
        } else {
            count += 2; // Surrogate pair
        }

        i += cp_len;
    }

    return count;
}

/// Converts a UTF-16 code unit index to a UTF-8 byte index
///
/// This is critical for ECMAScript compatibility where all string indices
/// are based on UTF-16 code units, but Zig strings are UTF-8 bytes.
///
/// Returns the byte index in the UTF-8 string that corresponds to the
/// given UTF-16 code unit index.
///
/// For surrogate pairs, both indices (high and low surrogate) point to
/// the same byte position (the start of the UTF-8 sequence).
///
/// Returns error.IndexOutOfBounds if utf16_index is beyond the string length.
pub fn utf16IndexToByte(str: []const u8, utf16_index: usize) Utf16Error!usize {
    var utf16_count: usize = 0;
    var byte_index: usize = 0;

    while (byte_index < str.len) {
        if (utf16_count == utf16_index) {
            return byte_index;
        }

        const cp_len = std.unicode.utf8ByteSequenceLength(str[byte_index]) catch {
            // Invalid UTF-8, treat as single byte
            byte_index += 1;
            utf16_count += 1;
            continue;
        };

        if (byte_index + cp_len > str.len) {
            // Incomplete sequence
            break;
        }

        const codepoint = std.unicode.utf8Decode(str[byte_index .. byte_index + cp_len]) catch {
            // Invalid sequence, treat as single byte
            byte_index += 1;
            utf16_count += 1;
            continue;
        };

        // Check if this code point is a surrogate pair
        if (codepoint <= 0xFFFF) {
            // Single UTF-16 code unit
            utf16_count += 1;
        } else {
            // Surrogate pair (2 UTF-16 code units)
            // If utf16_index points to either the high or low surrogate,
            // both should return the same byte position
            if (utf16_count + 1 == utf16_index) {
                return byte_index; // Points to the low surrogate
            }
            utf16_count += 2;
        }

        byte_index += cp_len;
    }

    // If we reached the exact index at the end of string
    if (utf16_count == utf16_index) {
        return byte_index;
    }

    return error.IndexOutOfBounds;
}

/// Converts a UTF-8 byte index to a UTF-16 code unit index
///
/// This is useful for converting results from byte-based operations
/// back to ECMAScript-compatible UTF-16 indices.
pub fn byteIndexToUtf16(str: []const u8, byte_index: usize) Utf16Error!usize {
    if (byte_index > str.len) return error.IndexOutOfBounds;

    var utf16_count: usize = 0;
    var i: usize = 0;

    while (i < byte_index) {
        const cp_len = std.unicode.utf8ByteSequenceLength(str[i]) catch {
            i += 1;
            utf16_count += 1;
            continue;
        };

        if (i + cp_len > str.len) {
            break;
        }

        const codepoint = std.unicode.utf8Decode(str[i .. i + cp_len]) catch {
            i += 1;
            utf16_count += 1;
            continue;
        };

        if (codepoint <= 0xFFFF) {
            utf16_count += 1;
        } else {
            utf16_count += 2;
        }

        i += cp_len;
    }

    return utf16_count;
}

/// Returns the UTF-16 code unit at the given UTF-16 index
///
/// For code points in BMP (U+0000 to U+FFFF), this returns the code point itself.
/// For code points above BMP, this returns either the high or low surrogate
/// depending on the index.
///
/// Examples:
///   codeUnitAt("A", 0) -> 0x0041
///   codeUnitAt("😀", 0) -> 0xD83D (high surrogate)
///   codeUnitAt("😀", 1) -> 0xDE00 (low surrogate)
pub fn codeUnitAt(str: []const u8, utf16_index: usize) Utf16Error!u16 {
    const byte_idx = try utf16IndexToByte(str, utf16_index);

    if (byte_idx >= str.len) {
        return error.IndexOutOfBounds;
    }

    const cp_len = std.unicode.utf8ByteSequenceLength(str[byte_idx]) catch {
        return error.InvalidUtf8;
    };

    if (byte_idx + cp_len > str.len) {
        return error.InvalidUtf8;
    }

    const codepoint = std.unicode.utf8Decode(str[byte_idx .. byte_idx + cp_len]) catch {
        return error.InvalidUtf8;
    };

    // If code point is in BMP, return it directly
    if (codepoint <= 0xFFFF) {
        return @intCast(codepoint);
    }

    // Code point requires surrogate pair
    // Calculate which part of the pair we need
    const adjusted = codepoint - 0x10000;
    const high_surrogate: u16 = 0xD800 + @as(u16, @intCast((adjusted >> 10) & 0x3FF));
    const low_surrogate: u16 = 0xDC00 + @as(u16, @intCast(adjusted & 0x3FF));

    // Check if we're at the high or low surrogate position
    var utf16_count: usize = 0;
    var i: usize = 0;

    while (i < byte_idx) {
        const len = std.unicode.utf8ByteSequenceLength(str[i]) catch {
            i += 1;
            utf16_count += 1;
            continue;
        };

        if (i + len <= str.len) {
            const cp = std.unicode.utf8Decode(str[i .. i + len]) catch {
                i += 1;
                utf16_count += 1;
                continue;
            };

            if (cp <= 0xFFFF) {
                utf16_count += 1;
            } else {
                utf16_count += 2;
            }
        }

        i += len;
    }

    // If we're at the first code unit of this character, return high surrogate
    // If we're at the second code unit (utf16_index is odd within this char), return low
    if (utf16_count == utf16_index) {
        return high_surrogate;
    } else {
        return low_surrogate;
    }
}

// Tests
test "lengthUtf16 - ASCII" {
    try std.testing.expectEqual(@as(usize, 5), lengthUtf16("hello"));
    try std.testing.expectEqual(@as(usize, 0), lengthUtf16(""));
    try std.testing.expectEqual(@as(usize, 1), lengthUtf16("a"));
}

test "lengthUtf16 - Unicode BMP" {
    try std.testing.expectEqual(@as(usize, 4), lengthUtf16("café")); // é is 1 code unit
    try std.testing.expectEqual(@as(usize, 2), lengthUtf16("你好")); // Each CJK char is 1 code unit
    try std.testing.expectEqual(@as(usize, 6), lengthUtf16("Straße")); // ß is 1 code unit
}

test "lengthUtf16 - Surrogate pairs (emojis)" {
    try std.testing.expectEqual(@as(usize, 2), lengthUtf16("😀")); // 1 emoji = 2 code units
    try std.testing.expectEqual(@as(usize, 4), lengthUtf16("😀😃")); // 2 emojis = 4 code units
    try std.testing.expectEqual(@as(usize, 7), lengthUtf16("hello😀")); // 5 + 2 = 7
}

test "utf16IndexToByte - ASCII" {
    const str = "hello";
    try std.testing.expectEqual(@as(usize, 0), try utf16IndexToByte(str, 0));
    try std.testing.expectEqual(@as(usize, 1), try utf16IndexToByte(str, 1));
    try std.testing.expectEqual(@as(usize, 4), try utf16IndexToByte(str, 4));
    try std.testing.expectEqual(@as(usize, 5), try utf16IndexToByte(str, 5)); // End of string
}

test "utf16IndexToByte - Unicode BMP" {
    const str = "café"; // c=1byte, a=1byte, f=1byte, é=2bytes
    try std.testing.expectEqual(@as(usize, 0), try utf16IndexToByte(str, 0)); // 'c'
    try std.testing.expectEqual(@as(usize, 1), try utf16IndexToByte(str, 1)); // 'a'
    try std.testing.expectEqual(@as(usize, 2), try utf16IndexToByte(str, 2)); // 'f'
    try std.testing.expectEqual(@as(usize, 3), try utf16IndexToByte(str, 3)); // 'é' start
}

test "utf16IndexToByte - Emoji (surrogate pair)" {
    const str = "😀"; // 4 bytes in UTF-8, 2 code units in UTF-16
    try std.testing.expectEqual(@as(usize, 0), try utf16IndexToByte(str, 0)); // High surrogate position
    try std.testing.expectEqual(@as(usize, 0), try utf16IndexToByte(str, 1)); // Low surrogate (same byte start)
    try std.testing.expectEqual(@as(usize, 4), try utf16IndexToByte(str, 2)); // End of string
}

test "utf16IndexToByte - Mixed content" {
    const str = "a😀b"; // a=1byte, emoji=4bytes, b=1byte; UTF-16: a=1, emoji=2, b=1 = 4 total
    try std.testing.expectEqual(@as(usize, 0), try utf16IndexToByte(str, 0)); // 'a'
    try std.testing.expectEqual(@as(usize, 1), try utf16IndexToByte(str, 1)); // emoji high surrogate
    try std.testing.expectEqual(@as(usize, 1), try utf16IndexToByte(str, 2)); // emoji low surrogate
    try std.testing.expectEqual(@as(usize, 5), try utf16IndexToByte(str, 3)); // 'b'
}

test "byteIndexToUtf16" {
    const str = "a😀b";
    try std.testing.expectEqual(@as(usize, 0), try byteIndexToUtf16(str, 0)); // Before 'a'
    try std.testing.expectEqual(@as(usize, 1), try byteIndexToUtf16(str, 1)); // Before emoji
    try std.testing.expectEqual(@as(usize, 3), try byteIndexToUtf16(str, 5)); // Before 'b'
}

test "codeUnitAt - ASCII" {
    const str = "ABC";
    try std.testing.expectEqual(@as(u16, 0x0041), try codeUnitAt(str, 0)); // 'A'
    try std.testing.expectEqual(@as(u16, 0x0042), try codeUnitAt(str, 1)); // 'B'
    try std.testing.expectEqual(@as(u16, 0x0043), try codeUnitAt(str, 2)); // 'C'
}

test "codeUnitAt - Emoji surrogate pair" {
    const str = "😀"; // U+1F600
    const high = try codeUnitAt(str, 0);
    const low = try codeUnitAt(str, 1);

    // 😀 = U+1F600
    // High surrogate: 0xD800 + ((0x1F600 - 0x10000) >> 10) = 0xD83D
    // Low surrogate: 0xDC00 + ((0x1F600 - 0x10000) & 0x3FF) = 0xDE00
    try std.testing.expectEqual(@as(u16, 0xD83D), high);
    try std.testing.expectEqual(@as(u16, 0xDE00), low);
}
