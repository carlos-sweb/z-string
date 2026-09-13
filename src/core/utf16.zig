const std = @import("std");

/// Errors that can occur during UTF-16 operations
pub const Utf16Error = error{
    InvalidUtf8,
    InvalidUtf16,
    IndexOutOfBounds,
    InvalidCodePoint,
};

/// z-string-surrogate-charat.md: a JS string is a sequence of UTF-16
/// code units, not Unicode scalar values -- an unpaired surrogate
/// (0xD800-0xDFFF alone, without its other half) is invalid as real
/// UTF-8 (surrogates aren't valid Unicode scalar values), but IS a
/// legal JS string value (`"😀".charAt(1)`, `"\uD800"`,
/// `String.fromCharCode(0xD800)` all produce/consume one). This
/// module represents a lone surrogate using WTF-8 (Wobbly
/// Transformation Format-8, the same encoding V8/SpiderMonkey use
/// internally for exactly this): the identical 3-byte bit layout
/// ordinary UTF-8 already uses for any codepoint in 0x0800-0xFFFF,
/// which `std.unicode`'s own encoder/decoder reject as invalid
/// specifically because U+D800-U+DFFF aren't valid standalone
/// scalar values. Every forward/backward UTF-8 walk in this library
/// must recognize this exact byte shape as ONE UTF-16 unit (3 bytes),
/// not fall through to the generic "invalid byte" fallback (which
/// would miscount it as 3 separate units).
/// Encodes a lone UTF-16 surrogate (0xD800-0xDFFF) as a 3-byte WTF-8
/// sequence into `buf`. Caller guarantees `surrogate` is in range.
pub fn encodeSurrogateWtf8(buf: *[3]u8, surrogate: u16) void {
    buf[0] = 0xE0 | @as(u8, @intCast(surrogate >> 12));
    buf[1] = 0x80 | @as(u8, @intCast((surrogate >> 6) & 0x3F));
    buf[2] = 0x80 | @as(u8, @intCast(surrogate & 0x3F));
}

/// If `bytes` (exactly 3 bytes) is this library's WTF-8 encoding of a
/// lone surrogate, returns its value; null for any other 3-byte
/// sequence (valid 3-byte UTF-8 or genuinely invalid bytes -- callers
/// already know `std.unicode.utf8Decode` rejected it before reaching
/// here, since a valid non-surrogate codepoint would have decoded
/// successfully).
pub fn decodeSurrogateWtf8(bytes: []const u8) ?u16 {
    if (bytes.len != 3) return null;
    if (bytes[0] & 0xF0 != 0xE0) return null;
    if (bytes[1] & 0xC0 != 0x80 or bytes[2] & 0xC0 != 0x80) return null;
    const value: u21 = (@as(u21, bytes[0] & 0x0F) << 12) | (@as(u21, bytes[1] & 0x3F) << 6) | (bytes[2] & 0x3F);
    if (value < 0xD800 or value > 0xDFFF) return null;
    return @intCast(value);
}

/// Joins `left ++ right`, canonicalizing the boundary: if `left` ends
/// with a WTF-8-encoded HIGH surrogate and `right` begins with a
/// WTF-8-encoded LOW surrogate (see `encodeSurrogateWtf8`), the two
/// are merged into the single real 4-byte UTF-8 sequence for the
/// combined astral codepoint. Real JS strings are just UTF-16 code
/// unit sequences -- there's no such thing as "this character came
/// from concatenating two halves" being observable
/// (`String.fromCharCode(0xD83D) + String.fromCharCode(0xDE00) ===
/// "😀"` is true in real JS/Node, confirmed). This engine's
/// byte-based storage needs this explicit canonicalization at every
/// concat site so the SAME logical string always has ONE byte
/// representation -- otherwise byte-level equality/hashing/property
/// keys would silently disagree depending on how a string was built
/// (z-string-surrogate-charat.md).
pub fn concatUtf8(allocator: std.mem.Allocator, left: []const u8, right: []const u8) ![]u8 {
    if (mergeSurrogateBoundary(left, right)) |merged| {
        const out = try allocator.alloc(u8, (left.len - 3) + 4 + (right.len - 3));
        @memcpy(out[0 .. left.len - 3], left[0 .. left.len - 3]);
        @memcpy(out[left.len - 3 ..][0..4], &merged);
        @memcpy(out[left.len - 3 + 4 ..], right[3..]);
        return out;
    }
    return std.mem.concat(allocator, u8, &.{ left, right });
}

/// If `left` ends with a WTF-8-encoded HIGH surrogate and `right`
/// begins with a WTF-8-encoded LOW surrogate, returns the 4-byte real
/// UTF-8 encoding of the combined astral codepoint (which replaces
/// those 6 bytes -- see `concatUtf8`'s own doc comment for why every
/// multi-piece string-building site needs this same check at each
/// new boundary, not just simple two-piece concatenation).
pub fn mergeSurrogateBoundary(left: []const u8, right: []const u8) ?[4]u8 {
    if (left.len < 3 or right.len < 3) return null;
    const high = decodeSurrogateWtf8(left[left.len - 3 ..]) orelse return null;
    if (high < 0xD800 or high > 0xDBFF) return null;
    const low = decodeSurrogateWtf8(right[0..3]) orelse return null;
    if (low < 0xDC00 or low > 0xDFFF) return null;
    const cp: u21 = 0x10000 + (@as(u21, high - 0xD800) << 10) + (@as(u21, low - 0xDC00));
    var buf: [4]u8 = undefined;
    _ = std.unicode.utf8Encode(cp, &buf) catch unreachable; // always in 0x10000-0x10FFFF by construction
    return buf;
}

/// Converts this library's internal WTF-8 (see `encodeSurrogateWtf8`)
/// to well-formed, real UTF-8 by replacing every lone surrogate with
/// the standard replacement character U+FFFD -- what any REAL UTF-8
/// consumer (a terminal, a file, a network socket) must receive,
/// since actual UTF-8 cannot express an unpaired surrogate at all.
/// Every JS-visible string operation (length, charAt, slice,
/// concatenation, ...) works on the raw WTF-8 bytes directly and
/// never needs this; only the boundary where those bytes leave the
/// engine as "real UTF-8 text" does (console.log, JSON.stringify,
/// uncaught-exception printing, ...). Always allocates a fresh copy,
/// even when `str` has no lone surrogate to replace -- simpler
/// ownership for callers than a maybe-borrowed result, and this only
/// runs at output boundaries, not on any hot path.
pub fn sanitizeWtf8ToUtf8(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < str.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(str[i]) catch {
            try out.append(allocator, str[i]);
            i += 1;
            continue;
        };
        if (i + cp_len > str.len) {
            try out.appendSlice(allocator, str[i..]);
            break;
        }
        if (cp_len == 3 and decodeSurrogateWtf8(str[i .. i + 3]) != null) {
            try out.appendSlice(allocator, "\xEF\xBF\xBD"); // U+FFFD
            i += 3;
            continue;
        }
        try out.appendSlice(allocator, str[i .. i + cp_len]);
        i += cp_len;
    }
    return out.toOwnedSlice(allocator);
}

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
            // This library's own WTF-8 lone-surrogate encoding (see
            // encodeSurrogateWtf8) is exactly one UTF-16 unit, 3 bytes
            // -- not the generic "invalid, 1 byte" fallback below.
            if (cp_len == 3 and decodeSurrogateWtf8(str[i .. i + 3]) != null) {
                i += 3;
                count += 1;
                continue;
            }
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
            // Incomplete sequence: not enough bytes remain in the whole
            // string to complete it. If byte_index lands exactly at the
            // end of the string, this trailing run is a single UTF-16
            // unit (matching lengthUtf16/utf16IndexToBytePos), so count
            // it -- otherwise byteIndexToUtf16(str, str.len) would
            // disagree with lengthUtf16(str) by one. If byte_index
            // instead lands *inside* this run, there is no clean unit
            // boundary there, so leave utf16_count at the run's start.
            if (byte_index >= str.len) {
                utf16_count += 1;
            }
            break;
        }

        const codepoint = std.unicode.utf8Decode(str[i .. i + cp_len]) catch {
            if (cp_len == 3 and decodeSurrogateWtf8(str[i .. i + 3]) != null) {
                i += 3;
                utf16_count += 1;
                continue;
            }
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
            // Incomplete sequence at the end of the string. lengthUtf16
            // counts this trailing partial sequence as one unit too (see
            // its own "Incomplete sequence at end" branch), so this walk
            // must agree: without counting it here, an index equal to the
            // string's own reported UTF-16 length (the common "end of
            // string" case, e.g. slice()'s default `end`) would incorrectly
            // report out-of-bounds instead of resolving to str.len.
            utf16_count += 1;
            byte_index = str.len;
            break;
        }

        const codepoint = std.unicode.utf8Decode(str[byte_index .. byte_index + cp_len]) catch {
            if (cp_len == 3 and decodeSurrogateWtf8(str[byte_index .. byte_index + 3]) != null) {
                byte_index += 3;
                utf16_count += 1;
                continue;
            }
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
    _ = std.unicode.utf8Decode(str[start..pos]) catch {
        // A well-formed 3-byte WTF-8 lone surrogate (see
        // encodeSurrogateWtf8) is exactly one previous code unit,
        // starting at `start` -- not the generic "invalid, back up one
        // raw byte" fallback.
        if (seq_len == 3 and decodeSurrogateWtf8(str[start..pos]) != null) return start;
        return pos - 1;
    };
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
    return (try utf16IndexFromEndToBytePos(str, count_from_end)).byte_index;
}

/// Same as `utf16IndexFromEndToByte`, but also reports whether
/// `count_from_end` landed on the low-surrogate half of a surrogate
/// pair (see `Utf16Position`) -- `at()`'s negative-index path needs
/// this to return just that half, WTF-8-encoded, not the whole pair.
pub fn utf16IndexFromEndToBytePos(str: []const u8, count_from_end: usize) Utf16Error!Utf16Position {
    if (count_from_end == 0) return error.IndexOutOfBounds;

    var pos = str.len;
    var remaining = count_from_end;

    while (pos > 0) {
        const start = prevCodepointStart(str, pos);
        const span_len = pos - start;
        // A 4-byte UTF-8 sequence always decodes to an astral code point
        // (U+10000-U+10FFFF), which is always 2 UTF-16 units; every other
        // span (1-3 valid bytes, a 3-byte WTF-8 lone surrogate, or the
        // 1-byte invalid fallback) is 1 unit.
        const units: usize = if (span_len == 4) 2 else 1;

        if (remaining <= units) {
            return .{ .byte_index = start, .is_low_surrogate = units == 2 and remaining == 1 };
        }
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
        // An existing WTF-8 lone surrogate already in the string (see
        // encodeSurrogateWtf8) -- e.g. from a prior charAt()/at() on
        // an astral pair -- reads back as its own code unit value
        // directly, not an error.
        if (cp_len == 3) {
            if (decodeSurrogateWtf8(str[byte_idx .. byte_idx + 3])) |surrogate| return surrogate;
        }
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

test "utf16IndexToByte - agrees with lengthUtf16 on a truncated trailing sequence" {
    // 'a' followed by a 2-byte lead (0xC3) with no continuation byte.
    // lengthUtf16 counts the incomplete tail as its own unit (2 total), so
    // the index equal to that count ("end of string") must resolve to
    // str.len here too, not report out of bounds.
    const str = "a\xC3";
    try std.testing.expectEqual(@as(usize, 2), lengthUtf16(str));
    try std.testing.expectEqual(@as(usize, 0), try utf16IndexToByte(str, 0));
    try std.testing.expectEqual(@as(usize, 1), try utf16IndexToByte(str, 1));
    try std.testing.expectEqual(@as(usize, str.len), try utf16IndexToByte(str, 2));
    try std.testing.expectError(error.IndexOutOfBounds, utf16IndexToByte(str, 3));
}

test "byteIndexToUtf16" {
    const str = "a😀b";
    try std.testing.expectEqual(@as(usize, 0), try byteIndexToUtf16(str, 0)); // Before 'a'
    try std.testing.expectEqual(@as(usize, 1), try byteIndexToUtf16(str, 1)); // Before emoji
    try std.testing.expectEqual(@as(usize, 3), try byteIndexToUtf16(str, 5)); // Before 'b'
}

test "byteIndexToUtf16 - agrees with lengthUtf16 at the end of a truncated trailing sequence" {
    // "aaa" + a 3-byte lead (0xE0) with only one of its two continuation
    // bytes present ('b' isn't a valid continuation byte either way):
    // lengthUtf16 counts the whole incomplete tail as a single unit, so
    // byteIndexToUtf16(str, str.len) must return that same count (4), not
    // stop one short the way utf16IndexToByte's own truncated-tail fix
    // already had to guard against.
    const str = "aaa\xE0b";
    try std.testing.expectEqual(@as(usize, 4), lengthUtf16(str));
    try std.testing.expectEqual(@as(usize, 4), try byteIndexToUtf16(str, str.len));
    try std.testing.expectEqual(@as(usize, str.len), try utf16IndexToByte(str, 4));
}

test "byteIndexToUtf16 - a byte offset landing inside a truncated tail resolves to the unit's start" {
    // Same string, but asking about byte 4 (the 'b', mid-way through the
    // incomplete unit) instead of str.len: there's no clean UTF-16
    // boundary there, so this should resolve to the tail unit's own
    // index (3), not be pulled forward to 4 like the str.len case above.
    const str = "aaa\xE0b";
    try std.testing.expectEqual(@as(usize, 3), try byteIndexToUtf16(str, 4));
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
