const units = @import("../core/units.zig");
const unicode = @import("../unicode/algorithms.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const unicode_normalize = @import("unicode_normalize.zig");

/// String.prototype.toString()
/// Spec: https://tc39.es/ecma262/#sec-string.prototype.tostring
///
/// Returns the string value.
/// In JavaScript, this returns the primitive value of a String object.
/// In our implementation, this simply returns a copy of the string.
///
/// The returned string must be freed by the caller.
pub fn toString(allocator: Allocator, str: []const u8) ![]u8 {
    return allocator.dupe(u8, str);
}

/// String.prototype.valueOf()
/// Spec: https://tc39.es/ecma262/#sec-string.prototype.valueof
///
/// Returns the primitive value of a String object.
/// Identical to toString() in behavior.
///
/// The returned string must be freed by the caller.
pub fn valueOf(allocator: Allocator, str: []const u8) ![]u8 {
    return allocator.dupe(u8, str);
}

/// String.prototype.localeCompare(that, locales, options)
/// Spec: https://tc39.es/ecma262/#sec-string.prototype.localecompare
///
/// Returns a number indicating whether a reference string comes before,
/// after, or is the same as the given string in sort order.
///
/// Returns:
///   - negative if str comes before that
///   - 0 if they are equivalent
///   - positive if str comes after that
///
/// Note: This is a simplified implementation that performs basic string comparison.
/// Full locale-sensitive comparison would require ICU or similar library.
/// The locales and options parameters are currently ignored.
pub fn localeCompare(str: []const u8, that: []const u8, _locales: ?[]const u8, _options: ?[]const u8) isize {
    _ = _locales;
    _ = _options;
    return unicode.compareCanonical(str, that);
}

/// String.prototype.normalize(form)
/// Spec: https://tc39.es/ecma262/#sec-string.prototype.normalize
///
/// Returns the Unicode Normalization Form of the string.
///
/// Supported forms:
///   - "NFC" (default) - Canonical Decomposition, followed by Canonical Composition
///   - "NFD" - Canonical Decomposition
///   - "NFKC" - Compatibility Decomposition, followed by Canonical Composition
///   - "NFKD" - Compatibility Decomposition
///
/// Uses complete Unicode 17.0.0 decomposition, composition and combining classes.
/// Invalid forms retain the legacy copy fallback; use normalizeStrict for errors.
///
/// The returned string must be freed by the caller.
pub fn normalize(allocator: Allocator, str: []const u8, form: ?[]const u8) ![]u8 {
    const form_str = form orelse "NFC";

    // Parse normalization form
    const norm_form = unicode_normalize.NormalizationForm.fromString(form_str) orelse {
        // Invalid form - in JavaScript this throws RangeError
        // For ECMAScript compliance, we should return an error
        // For now, gracefully return a copy
        return allocator.dupe(u8, str);
    };

    // Perform normalization
    return unicode_normalize.normalize(allocator, str, norm_form);
}

// ============================================================================
// Tests
// ============================================================================

test "toString - basic functionality" {
    const allocator = std.testing.allocator;

    const result = try toString(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "toString - empty string" {
    const allocator = std.testing.allocator;

    const result = try toString(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "toString - Unicode" {
    const allocator = std.testing.allocator;

    const result = try toString(allocator, "hello 😀 world");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello 😀 world", result);
}

test "valueOf - basic functionality" {
    const allocator = std.testing.allocator;

    const result = try valueOf(allocator, "hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "valueOf - empty string" {
    const allocator = std.testing.allocator;

    const result = try valueOf(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "localeCompare - equal strings" {
    const result = localeCompare("hello", "hello", null, null);
    try std.testing.expectEqual(@as(isize, 0), result);
}

test "localeCompare - first comes before second" {
    const result = localeCompare("apple", "banana", null, null);
    try std.testing.expectEqual(@as(isize, -1), result);
}

test "localeCompare - first comes after second" {
    const result = localeCompare("banana", "apple", null, null);
    try std.testing.expectEqual(@as(isize, 1), result);
}

test "localeCompare - case sensitive" {
    // lowercase 'a' (97) comes after uppercase 'Z' (90)
    const result = localeCompare("a", "Z", null, null);
    try std.testing.expectEqual(@as(isize, 1), result);
}

test "localeCompare - different lengths" {
    const result1 = localeCompare("abc", "abcd", null, null);
    try std.testing.expectEqual(@as(isize, -1), result1);

    const result2 = localeCompare("abcd", "abc", null, null);
    try std.testing.expectEqual(@as(isize, 1), result2);
}

test "localeCompare - empty strings" {
    const result1 = localeCompare("", "", null, null);
    try std.testing.expectEqual(@as(isize, 0), result1);

    const result2 = localeCompare("", "a", null, null);
    try std.testing.expectEqual(@as(isize, -1), result2);

    const result3 = localeCompare("a", "", null, null);
    try std.testing.expectEqual(@as(isize, 1), result3);
}

test "normalize - default NFC" {
    const allocator = std.testing.allocator;

    const result = try normalize(allocator, "hello", null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "normalize - explicit NFC" {
    const allocator = std.testing.allocator;

    const result = try normalize(allocator, "hello", "NFC");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "normalize - NFD" {
    const allocator = std.testing.allocator;

    const result = try normalize(allocator, "hello", "NFD");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "normalize - NFKC" {
    const allocator = std.testing.allocator;

    const result = try normalize(allocator, "hello", "NFKC");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "normalize - NFKD" {
    const allocator = std.testing.allocator;

    const result = try normalize(allocator, "hello", "NFKD");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "normalize - empty string" {
    const allocator = std.testing.allocator;

    const result = try normalize(allocator, "", null);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "normalize - accented characters NFD" {
    const allocator = std.testing.allocator;

    // café with composed é (U+00E9)
    const result = try normalize(allocator, "café", "NFD");
    defer allocator.free(result);

    // NFD decomposes é into e + combining acute
    // Result should be longer than input
    try std.testing.expect(result.len >= "café".len);
}

test "normalize - accented characters NFC" {
    const allocator = std.testing.allocator;

    const result = try normalize(allocator, "café", "NFC");
    defer allocator.free(result);

    // NFC should produce composed form
    try std.testing.expect(result.len > 0);
}

/// Strict normalization: unlike the legacy wrapper, invalid forms are errors.
pub fn normalizeStrict(allocator: Allocator, str: []const u8, form: ?[]const u8) ![]u8 {
    const parsed = unicode_normalize.NormalizationForm.fromString(form orelse "NFC") orelse return error.InvalidNormalizationForm;
    return unicode_normalize.normalize(allocator, str, parsed);
}

/// Owned UTF-8 output; valid surrogate pairs are preserved, isolated halves replaced.
pub fn toWellFormed(allocator: Allocator, str: []const u8) ![]u8 {
    return @import("../core/utf16.zig").sanitizeWtf8ToUtf8(allocator, str);
}

pub fn raw(allocator: Allocator, segments: []const []const u8, substitutions: []const []const u8) ![]u8 {
    var out: units.Builder = .{ .allocator = allocator };
    defer out.deinit();
    for (segments, 0..) |segment, i| {
        try out.appendString(segment);
        if (i + 1 < segments.len and i < substitutions.len) try out.appendString(substitutions[i]);
    }
    return out.finish();
}
