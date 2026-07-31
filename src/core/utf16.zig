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

/// `utf16IndexToByte`'s result, additionally recording whether `utf16_index`
/// landed on the low-surrogate half of an astral (non-BMP) code point —
/// information `utf16IndexToByte` itself already computes internally while
/// walking, but previously discarded, forcing callers like `codeUnitAt` to
/// redo a second full forward pass just to recover it.
pub const Utf16Position = struct {
    byte_index: usize,
    is_low_surrogate: bool,
};

/// Same as `utf16IndexToByte`, but also reports whether `utf16_index` is the
/// low-surrogate half of a surrogate pair (see `Utf16Position`).
pub fn utf16IndexToBytePos(str: []const u8, utf16_index: usize) Utf16Error!Utf16Position {
    var utf16_count: usize = 0;
    var byte_index: usize = 0;

    while (byte_index < str.len) {
        if (utf16_count == utf16_index) {
            return .{ .byte_index = byte_index, .is_low_surrogate = false };
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
                return .{ .byte_index = byte_index, .is_low_surrogate = true };
            }
            utf16_count += 2;
        }

        byte_index += cp_len;
    }

    // If we reached the exact index at the end of string
    if (utf16_count == utf16_index) {
        return .{ .byte_index = byte_index, .is_low_surrogate = false };
    }

    return error.IndexOutOfBounds;
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
    return (try utf16IndexToBytePos(str, utf16_index)).byte_index;
}

/// Returns the byte offset where the code point immediately before `pos`
/// starts, without scanning from the beginning of `str`. Malformed UTF-8 is
/// treated as a single invalid byte, same as elsewhere in this module.
/// `pos` must be greater than 0 and at most `str.len`.
fn prevCodepointStart(str: []const u8, pos: usize) usize {
    var start = pos - 1;
    var steps_back: usize = 0;
    while (start > 0 and steps_back < 3 and (str[start] & 0xC0) == 0x80) {
        start -= 1;
        steps_back += 1;
    }

    const seq_len = std.unicode.utf8ByteSequenceLength(str[start]) catch return pos - 1;
    if (start + seq_len != pos) return pos - 1;
    _ = std.unicode.utf8Decode(str[start..pos]) catch return pos - 1;
    return start;
}

/// Converts a "count back from the end" UTF-16 offset (1 = the last code
/// unit, 2 = the second-to-last, ...) to a UTF-8 byte index, scanning
/// *backward* from the end of `str` instead of forward from the start.
///
/// This is what `at()` needs for negative indices: JavaScript's
/// `str.at(-n)` is defined as `str.at(str.length - n)`, but computing it
/// that way requires knowing `str.length` first (a full forward scan) and
/// then a second forward scan to the resulting index. Walking backward
/// avoids both — a UTF-8 code point is never more than 4 bytes, so finding
/// where the *previous* one starts is O(1) work per step, and the whole
/// walk costs O(count_from_end) instead of O(str.len).
///
/// As with `utf16IndexToByte`, both halves of a surrogate pair resolve to
/// the same byte position. Returns error.IndexOutOfBounds if
/// `count_from_end` is 0 or exceeds the string's UTF-16 length.
pub fn utf16IndexFromEndToByte(str: []const u8, count_from_end: usize) Utf16Error!usize {
    if (count_from_end == 0) return error.IndexOutOfBounds;

    var pos = str.len;
    var remaining = count_from_end;

    while (pos > 0) {
        const start = prevCodepointStart(str, pos);
        const span_len = pos - start;
        // A 4-byte UTF-8 sequence always decodes to an astral code point
        // (U+10000-U+10FFFF), which is always 2 UTF-16 units; every other
        // span (1-3 valid bytes, or the 1-byte invalid fallback) is 1 unit.
        const units: usize = if (span_len == 4) 2 else 1;

        if (remaining <= units) return start;
        remaining -= units;
        pos = start;
    }

    return error.IndexOutOfBounds;
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
    const pos = try utf16IndexToBytePos(str, utf16_index);
    const byte_idx = pos.byte_index;

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
    const adjusted = codepoint - 0x10000;
    const high_surrogate: u16 = 0xD800 + @as(u16, @intCast((adjusted >> 10) & 0x3FF));
    const low_surrogate: u16 = 0xDC00 + @as(u16, @intCast(adjusted & 0x3FF));

    return if (pos.is_low_surrogate) low_surrogate else high_surrogate;
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

test "utf16IndexFromEndToByte - ASCII, matches utf16IndexToByte from the forward count" {
    const str = "hello"; // len = 5
    // count_from_end 1 = last unit = utf16 index 4, 5 = first unit = index 0
    try std.testing.expectEqual(try utf16IndexToByte(str, 4), try utf16IndexFromEndToByte(str, 1));
    try std.testing.expectEqual(try utf16IndexToByte(str, 3), try utf16IndexFromEndToByte(str, 2));
    try std.testing.expectEqual(try utf16IndexToByte(str, 0), try utf16IndexFromEndToByte(str, 5));
}

test "utf16IndexFromEndToByte - out of bounds" {
    const str = "hello";
    try std.testing.expectError(error.IndexOutOfBounds, utf16IndexFromEndToByte(str, 6));
    try std.testing.expectError(error.IndexOutOfBounds, utf16IndexFromEndToByte(str, 0));
    try std.testing.expectError(error.IndexOutOfBounds, utf16IndexFromEndToByte("", 1));
}

test "utf16IndexFromEndToByte - Unicode BMP" {
    const str = "café"; // c=1,a=1,f=1,é=2 bytes; byte offsets 0,1,2,3
    try std.testing.expectEqual(@as(usize, 3), try utf16IndexFromEndToByte(str, 1)); // 'é'
    try std.testing.expectEqual(@as(usize, 2), try utf16IndexFromEndToByte(str, 2)); // 'f'
}

test "utf16IndexFromEndToByte - emoji (surrogate pair), both halves resolve to the same byte" {
    const str = "😀"; // 4 bytes, 2 UTF-16 units
    try std.testing.expectEqual(@as(usize, 0), try utf16IndexFromEndToByte(str, 1)); // low surrogate
    try std.testing.expectEqual(@as(usize, 0), try utf16IndexFromEndToByte(str, 2)); // high surrogate
    try std.testing.expectError(error.IndexOutOfBounds, utf16IndexFromEndToByte(str, 3));
}

test "utf16IndexFromEndToByte - mixed content matches forward-scan equivalents" {
    const str = "a😀b"; // UTF-16: a=1, emoji=2, b=1 (total 4)
    try std.testing.expectEqual(try utf16IndexToByte(str, 3), try utf16IndexFromEndToByte(str, 1)); // 'b'
    try std.testing.expectEqual(try utf16IndexToByte(str, 2), try utf16IndexFromEndToByte(str, 2)); // emoji low surrogate
    try std.testing.expectEqual(try utf16IndexToByte(str, 1), try utf16IndexFromEndToByte(str, 3)); // emoji high surrogate
    try std.testing.expectEqual(try utf16IndexToByte(str, 0), try utf16IndexFromEndToByte(str, 4)); // 'a'
}

test "utf16IndexFromEndToByte - malformed trailing bytes degrade to single-byte units" {
    // "a" followed by three orphan continuation bytes: no valid lead byte
    // precedes them, so each is its own 1-byte unit (4 units total).
    const str = "a\x80\x80\x80";
    try std.testing.expectEqual(@as(usize, 3), try utf16IndexFromEndToByte(str, 1));
    try std.testing.expectEqual(@as(usize, 2), try utf16IndexFromEndToByte(str, 2));
    try std.testing.expectEqual(@as(usize, 1), try utf16IndexFromEndToByte(str, 3));
    try std.testing.expectEqual(@as(usize, 0), try utf16IndexFromEndToByte(str, 4));
    try std.testing.expectError(error.IndexOutOfBounds, utf16IndexFromEndToByte(str, 5));
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
