const std = @import("std");
const Allocator = std.mem.Allocator;

/// Checks if a Unicode code point is considered whitespace according to ECMAScript spec
/// Spec: https://tc39.es/ecma262/2025/#sec-white-space
///
/// ECMAScript whitespace includes:
/// - U+0009 (TAB)
/// - U+000B (VT - Vertical Tab)
/// - U+000C (FF - Form Feed)
/// - U+0020 (SPACE)
/// - U+00A0 (NBSP - No-Break Space)
/// - U+FEFF (BOM - Zero Width No-Break Space)
/// - Line terminators: U+000A (LF), U+000D (CR), U+2028 (LS), U+2029 (PS)
/// - Unicode category Zs (Space Separator)
fn isWhitespace(codepoint: u21) bool {
    return switch (codepoint) {
        // White space characters
        0x0009, // TAB
        0x000B, // VT
        0x000C, // FF
        0x0020, // SPACE
        0x00A0, // NBSP
        0xFEFF, // BOM

        // Line terminators
        0x000A, // LF
        0x000D, // CR
        0x2028, // LS
        0x2029, // PS

        // Unicode Zs category (Space Separators)
        0x1680, // OGHAM SPACE MARK
        0x2000, // EN QUAD
        0x2001, // EM QUAD
        0x2002, // EN SPACE
        0x2003, // EM SPACE
        0x2004, // THREE-PER-EM SPACE
        0x2005, // FOUR-PER-EM SPACE
        0x2006, // SIX-PER-EM SPACE
        0x2007, // FIGURE SPACE
        0x2008, // PUNCTUATION SPACE
        0x2009, // THIN SPACE
        0x200A, // HAIR SPACE
        0x202F, // NARROW NO-BREAK SPACE
        0x205F, // MEDIUM MATHEMATICAL SPACE
        0x3000, // IDEOGRAPHIC SPACE
        => true,

        else => false,
    };
}

/// String.prototype.trim()
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.trim
///
/// Removes whitespace from both ends of a string.
/// Returns a new string without modifying the original.
///
/// Examples:
///   trim("  hello  ") -> "hello"
///   trim("\t\n  abc  \r\n") -> "abc"
///   trim("   ") -> ""
pub fn trim(allocator: Allocator, str: []const u8) ![]u8 {
    if (str.len == 0) {
        return allocator.alloc(u8, 0);
    }

    // Find first non-whitespace character
    var start_byte: usize = 0;
    var i: usize = 0;

    while (i < str.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(str[i]) catch {
            // Invalid UTF-8, stop here
            break;
        };

        if (i + cp_len > str.len) break;

        const codepoint = std.unicode.utf8Decode(str[i .. i + cp_len]) catch {
            break;
        };

        if (!isWhitespace(codepoint)) {
            start_byte = i;
            break;
        }

        i += cp_len;
    }

    // If entire string is whitespace
    if (i >= str.len) {
        return allocator.alloc(u8, 0);
    }

    // Find last non-whitespace character (scan backwards)
    var end_byte: usize = str.len;
    i = str.len;

    while (i > start_byte) {
        // Scan backwards to find start of previous character
        var char_start = i - 1;
        while (char_start > start_byte and (str[char_start] & 0xC0) == 0x80) {
            char_start -= 1;
        }

        const cp_len = std.unicode.utf8ByteSequenceLength(str[char_start]) catch break;
        if (char_start + cp_len > str.len) break;

        const codepoint = std.unicode.utf8Decode(str[char_start .. char_start + cp_len]) catch break;

        if (!isWhitespace(codepoint)) {
            end_byte = char_start + cp_len;
            break;
        }

        i = char_start;
    }

    // Return the trimmed string
    return allocator.dupe(u8, str[start_byte..end_byte]);
}

/// String.prototype.trimStart() / trimLeft()
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.trimstart
///
/// Removes whitespace from the beginning of a string.
/// trimLeft() is an alias for trimStart().
///
/// Examples:
///   trimStart("  hello  ") -> "hello  "
///   trimStart("\t\nabc") -> "abc"
pub fn trimStart(allocator: Allocator, str: []const u8) ![]u8 {
    if (str.len == 0) {
        return allocator.alloc(u8, 0);
    }

    // Find first non-whitespace character
    var start_byte: usize = 0;
    var i: usize = 0;

    while (i < str.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(str[i]) catch break;
        if (i + cp_len > str.len) break;

        const codepoint = std.unicode.utf8Decode(str[i .. i + cp_len]) catch break;

        if (!isWhitespace(codepoint)) {
            start_byte = i;
            break;
        }

        i += cp_len;
    }

    // If entire string is whitespace
    if (i >= str.len) {
        return allocator.alloc(u8, 0);
    }

    // Return from first non-whitespace to end
    return allocator.dupe(u8, str[start_byte..]);
}

/// Alias for trimStart()
pub const trimLeft = trimStart;

/// String.prototype.trimEnd() / trimRight()
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.trimend
///
/// Removes whitespace from the end of a string.
/// trimRight() is an alias for trimEnd().
///
/// Examples:
///   trimEnd("  hello  ") -> "  hello"
///   trimEnd("abc\t\n") -> "abc"
pub fn trimEnd(allocator: Allocator, str: []const u8) ![]u8 {
    if (str.len == 0) {
        return allocator.alloc(u8, 0);
    }

    // Find last non-whitespace character (scan backwards)
    var end_byte: usize = str.len;
    var i: usize = str.len;

    while (i > 0) {
        // Scan backwards to find start of previous character
        var char_start = i - 1;
        while (char_start > 0 and (str[char_start] & 0xC0) == 0x80) {
            char_start -= 1;
        }

        const cp_len = std.unicode.utf8ByteSequenceLength(str[char_start]) catch break;
        if (char_start + cp_len > str.len) break;

        const codepoint = std.unicode.utf8Decode(str[char_start .. char_start + cp_len]) catch break;

        if (!isWhitespace(codepoint)) {
            end_byte = char_start + cp_len;
            break;
        }

        i = char_start;
    }

    // If entire string is whitespace
    if (i == 0) {
        return allocator.alloc(u8, 0);
    }

    // Return from start to last non-whitespace
    return allocator.dupe(u8, str[0..end_byte]);
}

/// Alias for trimEnd()
pub const trimRight = trimEnd;

// ============================================================================
// Tests
// ============================================================================

test "isWhitespace - basic whitespace characters" {
    // Common whitespace
    try std.testing.expect(isWhitespace(0x0020)); // SPACE
    try std.testing.expect(isWhitespace(0x0009)); // TAB
    try std.testing.expect(isWhitespace(0x000A)); // LF
    try std.testing.expect(isWhitespace(0x000D)); // CR

    // Less common
    try std.testing.expect(isWhitespace(0x000B)); // VT
    try std.testing.expect(isWhitespace(0x000C)); // FF
    try std.testing.expect(isWhitespace(0x00A0)); // NBSP
    try std.testing.expect(isWhitespace(0xFEFF)); // BOM

    // Not whitespace
    try std.testing.expect(!isWhitespace(0x0041)); // 'A'
    try std.testing.expect(!isWhitespace(0x0030)); // '0'
}

test "trim - basic functionality" {
    const allocator = std.testing.allocator;

    // "  hello  ".trim() -> "hello"
    const result1 = try trim(allocator, "  hello  ");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello", result1);

    // "\t\nhello\r\n".trim() -> "hello"
    const result2 = try trim(allocator, "\t\nhello\r\n");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello", result2);

    // "hello".trim() -> "hello" (no whitespace)
    const result3 = try trim(allocator, "hello");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("hello", result3);
}

test "trim - all whitespace" {
    const allocator = std.testing.allocator;

    // "   ".trim() -> ""
    const result1 = try trim(allocator, "   ");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("", result1);

    // "\t\n\r".trim() -> ""
    const result2 = try trim(allocator, "\t\n\r");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("", result2);
}

test "trim - empty string" {
    const allocator = std.testing.allocator;

    const result = try trim(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "trim - preserves internal whitespace" {
    const allocator = std.testing.allocator;

    // "  hello world  ".trim() -> "hello world"
    const result = try trim(allocator, "  hello world  ");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "trim - Unicode whitespace" {
    const allocator = std.testing.allocator;

    // With NBSP (U+00A0)
    const nbsp = "\u{00A0}hello\u{00A0}";
    const result = try trim(allocator, nbsp);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "trimStart - basic functionality" {
    const allocator = std.testing.allocator;

    // "  hello  ".trimStart() -> "hello  "
    const result1 = try trimStart(allocator, "  hello  ");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello  ", result1);

    // "\t\nhello".trimStart() -> "hello"
    const result2 = try trimStart(allocator, "\t\nhello");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello", result2);

    // "hello".trimStart() -> "hello"
    const result3 = try trimStart(allocator, "hello");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("hello", result3);
}

test "trimStart - all whitespace" {
    const allocator = std.testing.allocator;

    const result = try trimStart(allocator, "   ");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "trimEnd - basic functionality" {
    const allocator = std.testing.allocator;

    // "  hello  ".trimEnd() -> "  hello"
    const result1 = try trimEnd(allocator, "  hello  ");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("  hello", result1);

    // "hello\t\n".trimEnd() -> "hello"
    const result2 = try trimEnd(allocator, "hello\t\n");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello", result2);

    // "hello".trimEnd() -> "hello"
    const result3 = try trimEnd(allocator, "hello");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("hello", result3);
}

test "trimEnd - all whitespace" {
    const allocator = std.testing.allocator;

    const result = try trimEnd(allocator, "   ");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "trimStart vs trimEnd behavior" {
    const allocator = std.testing.allocator;
    const str = "  hello  ";

    const start_result = try trimStart(allocator, str);
    defer allocator.free(start_result);
    try std.testing.expectEqualStrings("hello  ", start_result);

    const end_result = try trimEnd(allocator, str);
    defer allocator.free(end_result);
    try std.testing.expectEqualStrings("  hello", end_result);

    const both_result = try trim(allocator, str);
    defer allocator.free(both_result);
    try std.testing.expectEqualStrings("hello", both_result);
}
