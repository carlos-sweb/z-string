const std = @import("std");
const Allocator = std.mem.Allocator;

/// String.prototype.toLowerCase()
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.tolowercase
///
/// Returns the calling string value converted to lower case.
/// For full Unicode case mapping, this implementation uses Unicode case folding rules.
///
/// Examples:
///   toLowerCase("HELLO") -> "hello"
///   toLowerCase("Hello World") -> "hello world"
///   toLowerCase("CAFÉ") -> "café"
///
/// The returned string must be freed by the caller.
pub fn toLowerCase(allocator: Allocator, str: []const u8) ![]u8 {
    // Allocate buffer for result (worst case: same size)
    // Note: Some Unicode transformations can change byte length
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < str.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(str[i]) catch {
            // Invalid UTF-8, copy as-is
            try result.append(allocator, str[i]);
            i += 1;
            continue;
        };

        if (i + cp_len > str.len) {
            // Incomplete sequence at end, copy as-is
            try result.append(allocator, str[i]);
            i += 1;
            continue;
        }

        const codepoint = std.unicode.utf8Decode(str[i .. i + cp_len]) catch {
            // Invalid UTF-8, copy as-is
            try result.append(allocator, str[i]);
            i += 1;
            continue;
        };

        // Convert to lowercase
        const lower = unicodeLower(codepoint);

        // Encode back to UTF-8
        var buf: [4]u8 = undefined;
        const encoded_len = std.unicode.utf8Encode(lower, &buf) catch {
            // Fallback: copy original
            try result.appendSlice(allocator, str[i .. i + cp_len]);
            i += cp_len;
            continue;
        };

        try result.appendSlice(allocator, buf[0..encoded_len]);
        i += cp_len;
    }

    return result.toOwnedSlice(allocator);
}

/// String.prototype.toUpperCase()
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.touppercase
///
/// Returns the calling string value converted to upper case.
/// For full Unicode case mapping, this implementation uses Unicode case folding rules.
///
/// Examples:
///   toUpperCase("hello") -> "HELLO"
///   toUpperCase("Hello World") -> "HELLO WORLD"
///   toUpperCase("café") -> "CAFÉ"
///
/// The returned string must be freed by the caller.
pub fn toUpperCase(allocator: Allocator, str: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < str.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(str[i]) catch {
            try result.append(allocator, str[i]);
            i += 1;
            continue;
        };

        if (i + cp_len > str.len) {
            try result.append(allocator, str[i]);
            i += 1;
            continue;
        }

        const codepoint = std.unicode.utf8Decode(str[i .. i + cp_len]) catch {
            try result.append(allocator, str[i]);
            i += 1;
            continue;
        };

        // Convert to uppercase
        const upper = unicodeUpper(codepoint);

        // Encode back to UTF-8
        var buf: [4]u8 = undefined;
        const encoded_len = std.unicode.utf8Encode(upper, &buf) catch {
            try result.appendSlice(allocator, str[i .. i + cp_len]);
            i += cp_len;
            continue;
        };

        try result.appendSlice(allocator, buf[0..encoded_len]);
        i += cp_len;
    }

    return result.toOwnedSlice(allocator);
}

/// String.prototype.toLocaleLowerCase(locale)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.tolocalelowercase
///
/// Returns the calling string value converted to lower case according to locale-specific
/// case mappings.
///
/// Note: This implementation currently uses the same logic as toLowerCase().
/// Full locale-specific case mapping (e.g., Turkish İ -> i) is not yet implemented.
///
/// The returned string must be freed by the caller.
pub fn toLocaleLowerCase(allocator: Allocator, str: []const u8, _locale: ?[]const u8) ![]u8 {
    // TODO: Implement locale-specific case mapping
    // For now, use standard toLowerCase
    _ = _locale;
    return toLowerCase(allocator, str);
}

/// String.prototype.toLocaleUpperCase(locale)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.tolocaleuppercase
///
/// Returns the calling string value converted to upper case according to locale-specific
/// case mappings.
///
/// Note: This implementation currently uses the same logic as toUpperCase().
/// Full locale-specific case mapping (e.g., Turkish i -> İ) is not yet implemented.
///
/// The returned string must be freed by the caller.
pub fn toLocaleUpperCase(allocator: Allocator, str: []const u8, _locale: ?[]const u8) ![]u8 {
    // TODO: Implement locale-specific case mapping
    _ = _locale;
    return toUpperCase(allocator, str);
}

// ============================================================================
// Unicode Case Mapping
// ============================================================================

/// Simple Unicode lowercase mapping
/// This covers the most common cases. Full Unicode case mapping would require
/// a complete case mapping table from the Unicode Character Database.
fn unicodeLower(cp: u21) u21 {
    // ASCII range
    if (cp >= 'A' and cp <= 'Z') {
        return cp + 32;
    }

    // Latin-1 Supplement (0x00C0 - 0x00FF)
    if (cp >= 0x00C0 and cp <= 0x00DE) {
        // Skip multiply sign (0x00D7)
        if (cp == 0x00D7) return cp;
        return cp + 32;
    }

    // Common Unicode uppercase letters
    // This is a simplified mapping. A complete implementation would use
    // the full Unicode case mapping tables.
    return switch (cp) {
        // Greek uppercase
        0x0391...0x03A9 => cp + 32, // Α-Ω -> α-ω
        0x0410...0x042F => cp + 32, // Cyrillic А-Я -> а-я

        // Add more mappings as needed
        else => cp,
    };
}

/// Simple Unicode uppercase mapping
fn unicodeUpper(cp: u21) u21 {
    // ASCII range
    if (cp >= 'a' and cp <= 'z') {
        return cp - 32;
    }

    // Latin-1 Supplement (0x00E0 - 0x00FF)
    if (cp >= 0x00E0 and cp <= 0x00FE) {
        // Skip division sign (0x00F7)
        if (cp == 0x00F7) return cp;
        return cp - 32;
    }

    // Common Unicode lowercase letters
    return switch (cp) {
        // Greek lowercase
        0x03B1...0x03C9 => cp - 32, // α-ω -> Α-Ω
        0x0430...0x044F => cp - 32, // Cyrillic а-я -> А-Я

        else => cp,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "toLowerCase - ASCII" {
    const allocator = std.testing.allocator;

    const result1 = try toLowerCase(allocator, "HELLO");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello", result1);

    const result2 = try toLowerCase(allocator, "Hello World");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello world", result2);

    const result3 = try toLowerCase(allocator, "ABC123");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("abc123", result3);
}

test "toLowerCase - already lowercase" {
    const allocator = std.testing.allocator;

    const result = try toLowerCase(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "toLowerCase - mixed case" {
    const allocator = std.testing.allocator;

    const result = try toLowerCase(allocator, "HeLLo WoRLd");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "toLowerCase - Unicode Latin" {
    const allocator = std.testing.allocator;

    const result = try toLowerCase(allocator, "CAFÉ");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("café", result);
}

test "toLowerCase - empty string" {
    const allocator = std.testing.allocator;

    const result = try toLowerCase(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "toUpperCase - ASCII" {
    const allocator = std.testing.allocator;

    const result1 = try toUpperCase(allocator, "hello");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("HELLO", result1);

    const result2 = try toUpperCase(allocator, "Hello World");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("HELLO WORLD", result2);

    const result3 = try toUpperCase(allocator, "abc123");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("ABC123", result3);
}

test "toUpperCase - already uppercase" {
    const allocator = std.testing.allocator;

    const result = try toUpperCase(allocator, "HELLO");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("HELLO", result);
}

test "toUpperCase - mixed case" {
    const allocator = std.testing.allocator;

    const result = try toUpperCase(allocator, "HeLLo WoRLd");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("HELLO WORLD", result);
}

test "toUpperCase - Unicode Latin" {
    const allocator = std.testing.allocator;

    const result = try toUpperCase(allocator, "café");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("CAFÉ", result);
}

test "toUpperCase - empty string" {
    const allocator = std.testing.allocator;

    const result = try toUpperCase(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "case conversion - round trip" {
    const allocator = std.testing.allocator;

    const original = "Hello World";

    const upper = try toUpperCase(allocator, original);
    defer allocator.free(upper);
    try std.testing.expectEqualStrings("HELLO WORLD", upper);

    const lower = try toLowerCase(allocator, upper);
    defer allocator.free(lower);
    try std.testing.expectEqualStrings("hello world", lower);
}

test "toLocaleLowerCase - basic functionality" {
    const allocator = std.testing.allocator;

    const result = try toLocaleLowerCase(allocator, "HELLO", null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "toLocaleUpperCase - basic functionality" {
    const allocator = std.testing.allocator;

    const result = try toLocaleUpperCase(allocator, "hello", null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("HELLO", result);
}
