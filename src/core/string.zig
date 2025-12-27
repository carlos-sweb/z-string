const std = @import("std");
const utf16 = @import("utf16.zig");
const access = @import("../methods/access.zig");
const search = @import("../methods/search.zig");
const transform = @import("../methods/transform.zig");
const padding = @import("../methods/padding.zig");
const trimming = @import("../methods/trimming.zig");
const split_methods = @import("../methods/split.zig");
const case = @import("../methods/case.zig");
const utility = @import("../methods/utility.zig");
const regex_methods = @import("../methods/regex.zig");

const Allocator = std.mem.Allocator;

/// ZString - ECMAScript-compatible string implementation
///
/// This struct wraps a UTF-8 string slice and provides an API that matches
/// JavaScript's String behavior, including UTF-16-based indexing and length.
///
/// The struct can be in two modes:
/// - Borrowed: Just wraps an existing string slice (allocator = null)
/// - Owned: Has allocated memory that must be freed (allocator != null)
pub const ZString = struct {
    /// Internal UTF-8 data
    data: []const u8,

    /// Allocator if this is an owned string, null if borrowed
    allocator: ?Allocator = null,

    /// Cached UTF-16 length (lazy-computed)
    cached_utf16_length: ?usize = null,

    /// Creates a ZString from a borrowed string slice
    /// The caller is responsible for ensuring the slice remains valid
    ///
    /// Example:
    ///   const zstr = ZString.init("hello");
    pub fn init(data: []const u8) ZString {
        return .{
            .data = data,
            .allocator = null,
            .cached_utf16_length = null,
        };
    }

    /// Creates an owned ZString by duplicating the provided data
    /// The returned ZString must be freed with deinit()
    ///
    /// Example:
    ///   var zstr = try ZString.initOwned(allocator, "hello");
    ///   defer zstr.deinit();
    pub fn initOwned(allocator: Allocator, data: []const u8) !ZString {
        const owned = try allocator.dupe(u8, data);
        return .{
            .data = owned,
            .allocator = allocator,
            .cached_utf16_length = null,
        };
    }

    /// Creates an owned ZString from existing owned data
    /// The ZString takes ownership of the data
    ///
    /// Example:
    ///   const data = try allocator.alloc(u8, 10);
    ///   var zstr = ZString.fromOwned(allocator, data);
    ///   defer zstr.deinit();
    pub fn fromOwned(allocator: Allocator, owned_data: []const u8) ZString {
        return .{
            .data = owned_data,
            .allocator = allocator,
            .cached_utf16_length = null,
        };
    }

    /// Frees the memory if this is an owned string
    /// Safe to call on borrowed strings (no-op)
    pub fn deinit(self: *ZString) void {
        if (self.allocator) |alloc| {
            alloc.free(self.data);
            self.allocator = null;
            self.data = "";
            self.cached_utf16_length = null;
        }
    }

    /// Returns the length of the string in UTF-16 code units
    /// This matches JavaScript's String.length behavior
    ///
    /// Examples:
    ///   ZString.init("hello").length() -> 5
    ///   ZString.init("😀").length() -> 2 (surrogate pair)
    ///   ZString.init("café").length() -> 4
    ///
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.length
    pub fn length(self: *ZString) usize {
        if (self.cached_utf16_length) |len| {
            return len;
        }

        const len = utf16.lengthUtf16(self.data);
        self.cached_utf16_length = len;
        return len;
    }

    /// Returns the length without caching (for const self)
    pub fn lengthConst(self: ZString) usize {
        return utf16.lengthUtf16(self.data);
    }

    /// Returns the byte length of the underlying UTF-8 data
    /// This is NOT spec-compliant but useful for Zig operations
    pub fn byteLength(self: ZString) usize {
        return self.data.len;
    }

    /// Checks if the string is empty
    pub fn isEmpty(self: ZString) bool {
        return self.data.len == 0;
    }

    /// Checks if this is an owned string
    pub fn isOwned(self: ZString) bool {
        return self.allocator != null;
    }

    /// Validates that the string contains valid UTF-8
    pub fn isWellFormed(self: ZString) bool {
        return std.unicode.utf8ValidateSlice(self.data);
    }

    /// Clones the string (always creates an owned copy)
    pub fn clone(self: ZString, allocator: Allocator) !ZString {
        return try initOwned(allocator, self.data);
    }

    /// Compares two strings for equality (byte-wise)
    pub fn eql(self: ZString, other: ZString) bool {
        return std.mem.eql(u8, self.data, other.data);
    }

    /// Compares with a string slice
    pub fn eqlSlice(self: ZString, other: []const u8) bool {
        return std.mem.eql(u8, self.data, other);
    }

    // ========================================================================
    // Character Access Methods
    // ========================================================================

    /// String.prototype.charAt(index)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.charat
    ///
    /// Returns a new string consisting of the single UTF-16 code unit at the given index.
    /// If index is out of bounds, returns an empty string.
    ///
    /// The returned string must be freed by the caller.
    pub fn charAt(self: ZString, allocator: Allocator, index: isize) ![]u8 {
        return access.charAt(allocator, self.data, index);
    }

    /// String.prototype.at(index)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.at
    ///
    /// Returns a new string consisting of the single UTF-16 code unit at the given index.
    /// Supports negative indexing (counts from the end).
    /// If index is out of bounds, returns null.
    ///
    /// The returned string (if not null) must be freed by the caller.
    pub fn at(self: ZString, allocator: Allocator, index: isize) !?[]u8 {
        return access.at(allocator, self.data, index);
    }

    /// String.prototype.charCodeAt(index)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.charcodeat
    ///
    /// Returns the UTF-16 code unit at the given index.
    /// If index is out of bounds, returns null (represents NaN in JS).
    pub fn charCodeAt(self: ZString, index: isize) ?u16 {
        return access.charCodeAt(self.data, index);
    }

    /// String.prototype.codePointAt(index)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.codepointat
    ///
    /// Returns the Unicode code point at the given index.
    /// Unlike charCodeAt, this correctly handles surrogate pairs.
    pub fn codePointAt(self: ZString, index: isize) ?u21 {
        return access.codePointAt(self.data, index);
    }

    // ========================================================================
    // Search Methods
    // ========================================================================

    /// String.prototype.indexOf(searchString, position)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.indexof
    ///
    /// Returns the index of the first occurrence of searchString, or -1 if not found.
    /// Starts searching at position (default 0).
    pub fn indexOf(self: ZString, searchString: []const u8, position: ?isize) isize {
        return search.indexOf(self.data, searchString, position);
    }

    /// String.prototype.lastIndexOf(searchString, position)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.lastindexof
    ///
    /// Returns the index of the last occurrence of searchString, or -1 if not found.
    /// Searches backwards from position (default end of string).
    pub fn lastIndexOf(self: ZString, searchString: []const u8, position: ?isize) isize {
        return search.lastIndexOf(self.data, searchString, position);
    }

    /// String.prototype.includes(searchString, position)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.includes
    ///
    /// Determines whether searchString appears within this string.
    /// Starts searching at position (default 0).
    pub fn includes(self: ZString, searchString: []const u8, position: ?isize) bool {
        return search.includes(self.data, searchString, position);
    }

    /// String.prototype.startsWith(searchString, position)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.startswith
    ///
    /// Determines whether this string begins with searchString.
    /// Optionally starts checking at position (default 0).
    pub fn startsWith(self: ZString, searchString: []const u8, position: ?isize) bool {
        return search.startsWith(self.data, searchString, position);
    }

    /// String.prototype.endsWith(searchString, endPosition)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.endswith
    ///
    /// Determines whether this string ends with searchString.
    /// Treats the string as if it were only endPosition characters long (default full length).
    pub fn endsWith(self: ZString, searchString: []const u8, endPosition: ?isize) bool {
        return search.endsWith(self.data, searchString, endPosition);
    }

    // ========================================================================
    // Transformation Methods
    // ========================================================================

    /// String.prototype.slice(start, end)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.slice
    ///
    /// Extracts a section of this string and returns it as a new string.
    /// Supports negative indices (count from end).
    ///
    /// The returned string must be freed by the caller.
    pub fn slice(self: ZString, allocator: Allocator, start: isize, end: ?isize) ![]u8 {
        return transform.slice(allocator, self.data, start, end);
    }

    /// String.prototype.substring(start, end)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.substring
    ///
    /// Returns the part of the string between start and end indices.
    /// Negative indices are treated as 0. If start > end, they are swapped.
    ///
    /// The returned string must be freed by the caller.
    pub fn substring(self: ZString, allocator: Allocator, start: isize, end: ?isize) ![]u8 {
        return transform.substring(allocator, self.data, start, end);
    }

    /// String.prototype.concat(...strings)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.concat
    ///
    /// Combines the text of one or more strings and returns a new string.
    ///
    /// The returned string must be freed by the caller.
    pub fn concat(self: ZString, allocator: Allocator, strings: []const []const u8) ![]u8 {
        return transform.concat(allocator, self.data, strings);
    }

    /// String.prototype.repeat(count)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.repeat
    ///
    /// Constructs and returns a new string containing the specified number
    /// of copies of this string concatenated together.
    ///
    /// The returned string must be freed by the caller.
    pub fn repeat(self: ZString, allocator: Allocator, count: isize) ![]u8 {
        return transform.repeat(allocator, self.data, count);
    }

    // ========================================================================
    // Padding Methods
    // ========================================================================

    /// String.prototype.padStart(targetLength, padString)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.padstart
    ///
    /// Pads the current string with another string (multiple times, if needed)
    /// until the resulting string reaches the given length.
    /// The padding is applied from the start of the current string.
    ///
    /// The returned string must be freed by the caller.
    pub fn padStart(self: ZString, allocator: Allocator, targetLength: isize, padString: ?[]const u8) ![]u8 {
        return padding.padStart(allocator, self.data, targetLength, padString);
    }

    /// String.prototype.padEnd(targetLength, padString)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.padend
    ///
    /// Pads the current string with another string (multiple times, if needed)
    /// until the resulting string reaches the given length.
    /// The padding is applied from the end of the current string.
    ///
    /// The returned string must be freed by the caller.
    pub fn padEnd(self: ZString, allocator: Allocator, targetLength: isize, padString: ?[]const u8) ![]u8 {
        return padding.padEnd(allocator, self.data, targetLength, padString);
    }

    // ========================================================================
    // Trimming Methods
    // ========================================================================

    /// String.prototype.trim()
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.trim
    ///
    /// Removes whitespace from both ends of a string.
    /// Returns a new string without modifying the original.
    ///
    /// The returned string must be freed by the caller.
    pub fn trim(self: ZString, allocator: Allocator) ![]u8 {
        return trimming.trim(allocator, self.data);
    }

    /// String.prototype.trimStart() / trimLeft()
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.trimstart
    ///
    /// Removes whitespace from the beginning of a string.
    ///
    /// The returned string must be freed by the caller.
    pub fn trimStart(self: ZString, allocator: Allocator) ![]u8 {
        return trimming.trimStart(allocator, self.data);
    }

    /// Alias for trimStart()
    pub const trimLeft = trimStart;

    /// String.prototype.trimEnd() / trimRight()
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.trimend
    ///
    /// Removes whitespace from the end of a string.
    ///
    /// The returned string must be freed by the caller.
    pub fn trimEnd(self: ZString, allocator: Allocator) ![]u8 {
        return trimming.trimEnd(allocator, self.data);
    }

    /// Alias for trimEnd()
    pub const trimRight = trimEnd;

    // ========================================================================
    // Split Methods
    // ========================================================================

    /// String.prototype.split(separator, limit)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.split
    ///
    /// Splits a String object into an array of strings by separating the string
    /// into substrings, using a specified separator string to determine where
    /// to make each split.
    ///
    /// Returns an array of strings. The caller is responsible for freeing both
    /// the array itself and each individual string in the array using freeSplitResult().
    pub fn split(self: ZString, allocator: Allocator, separator: ?[]const u8, limit: ?usize) ![][]u8 {
        return split_methods.split(allocator, self.data, separator, limit);
    }

    /// Helper to free the result of split()
    pub fn freeSplitResult(allocator: Allocator, result: [][]u8) void {
        split_methods.freeSplitResult(allocator, result);
    }

    // ========================================================================
    // Case Conversion Methods
    // ========================================================================

    /// String.prototype.toLowerCase()
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.tolowercase
    ///
    /// Returns the calling string value converted to lower case.
    ///
    /// The returned string must be freed by the caller.
    pub fn toLowerCase(self: ZString, allocator: Allocator) ![]u8 {
        return case.toLowerCase(allocator, self.data);
    }

    /// String.prototype.toUpperCase()
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.touppercase
    ///
    /// Returns the calling string value converted to upper case.
    ///
    /// The returned string must be freed by the caller.
    pub fn toUpperCase(self: ZString, allocator: Allocator) ![]u8 {
        return case.toUpperCase(allocator, self.data);
    }

    /// String.prototype.toLocaleLowerCase(locale)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.tolocalelowercase
    ///
    /// Returns the calling string value converted to lower case according to
    /// locale-specific case mappings.
    ///
    /// Note: Currently uses the same logic as toLowerCase().
    ///
    /// The returned string must be freed by the caller.
    pub fn toLocaleLowerCase(self: ZString, allocator: Allocator, locale: ?[]const u8) ![]u8 {
        return case.toLocaleLowerCase(allocator, self.data, locale);
    }

    /// String.prototype.toLocaleUpperCase(locale)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.tolocaleuppercase
    ///
    /// Returns the calling string value converted to upper case according to
    /// locale-specific case mappings.
    ///
    /// Note: Currently uses the same logic as toUpperCase().
    ///
    /// The returned string must be freed by the caller.
    pub fn toLocaleUpperCase(self: ZString, allocator: Allocator, locale: ?[]const u8) ![]u8 {
        return case.toLocaleUpperCase(allocator, self.data, locale);
    }

    // ========================================================================
    // Utility Methods
    // ========================================================================

    /// String.prototype.toString()
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.tostring
    ///
    /// Returns the string value.
    ///
    /// The returned string must be freed by the caller.
    pub fn toStringAlloc(self: ZString, allocator: Allocator) ![]u8 {
        return utility.toString(allocator, self.data);
    }

    /// String.prototype.valueOf()
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.valueof
    ///
    /// Returns the primitive value of a String object.
    ///
    /// The returned string must be freed by the caller.
    pub fn valueOfAlloc(self: ZString, allocator: Allocator) ![]u8 {
        return utility.valueOf(allocator, self.data);
    }

    /// String.prototype.localeCompare(that, locales, options)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.localecompare
    ///
    /// Returns a number indicating whether a reference string comes before,
    /// after, or is the same as the given string in sort order.
    ///
    /// Returns: negative if self < that, 0 if equal, positive if self > that
    ///
    /// Note: Simplified implementation without full locale support.
    pub fn localeCompare(self: ZString, that: []const u8, locales: ?[]const u8, options: ?[]const u8) isize {
        return utility.localeCompare(self.data, that, locales, options);
    }

    /// String.prototype.normalize(form)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.normalize
    ///
    /// Returns the Unicode Normalization Form of the string.
    ///
    /// Supported forms: "NFC" (default), "NFD", "NFKC", "NFKD"
    ///
    /// Note: Placeholder implementation. Full Unicode normalization not yet implemented.
    ///
    /// The returned string must be freed by the caller.
    pub fn normalize(self: ZString, allocator: Allocator, form: ?[]const u8) ![]u8 {
        return utility.normalize(allocator, self.data, form);
    }

    // ========================================================================
    // Regex Methods
    // ========================================================================

    /// String.prototype.search(regexp)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.search
    ///
    /// Executes a search for a match between a regular expression and this string,
    /// returning the index of the first match, or -1 if not found.
    ///
    /// Note: Requires zregexp dependency.
    pub fn searchRegex(self: ZString, allocator: Allocator, pattern: []const u8) !isize {
        return regex_methods.search(allocator, self.data, pattern);
    }

    /// String.prototype.match(regexp)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.match
    ///
    /// Retrieves the matches when matching a string against a regular expression.
    /// Returns an array of matches, or null if no match is found.
    ///
    /// The returned MatchArray (if not null) must be freed by calling deinit().
    ///
    /// Note: Requires zregexp dependency.
    pub fn matchRegex(self: ZString, allocator: Allocator, pattern: []const u8) !?regex_methods.MatchArray {
        return regex_methods.match(allocator, self.data, pattern);
    }

    /// String.prototype.matchAll(regexp)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.matchall
    ///
    /// Returns an iterator of all results matching a string against a regular expression,
    /// including capturing groups.
    ///
    /// The returned array and each MatchArray must be freed using freeMatchAllResult().
    ///
    /// Note: Requires zregexp dependency.
    pub fn matchAllRegex(self: ZString, allocator: Allocator, pattern: []const u8) ![]regex_methods.MatchArray {
        return regex_methods.matchAll(allocator, self.data, pattern);
    }

    /// Helper to free the result of matchAll()
    pub fn freeMatchAllResult(allocator: Allocator, matches: []regex_methods.MatchArray) void {
        regex_methods.freeMatchAll(allocator, matches);
    }

    /// String.prototype.replace(searchValue, replaceValue)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.replace
    ///
    /// Returns a new string with the first match of a pattern replaced by a replacement.
    /// The pattern can be a string or a RegExp.
    ///
    /// The returned string must be freed by the caller.
    ///
    /// Note: Requires zregexp dependency for regex patterns.
    pub fn replaceRegex(self: ZString, allocator: Allocator, pattern: []const u8, replacement: []const u8) ![]const u8 {
        return regex_methods.replace(allocator, self.data, pattern, replacement);
    }

    /// String.prototype.replaceAll(searchValue, replaceValue)
    /// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.replaceall
    ///
    /// Returns a new string with all matches of a pattern replaced by a replacement.
    /// The pattern can be a string or a RegExp.
    ///
    /// The returned string must be freed by the caller.
    ///
    /// Note: Requires zregexp dependency for regex patterns.
    pub fn replaceAllRegex(self: ZString, allocator: Allocator, pattern: []const u8, replacement: []const u8) ![]const u8 {
        return regex_methods.replaceAll(allocator, self.data, pattern, replacement);
    }
};

// Tests
test "ZString.init - borrowed string" {
    var zstr = ZString.init("hello");
    try std.testing.expectEqual(@as(usize, 5), zstr.length());
    try std.testing.expectEqual(@as(usize, 5), zstr.byteLength());
    try std.testing.expect(!zstr.isOwned());
    try std.testing.expect(!zstr.isEmpty());

    // Should be safe to call deinit on borrowed
    zstr.deinit();
}

test "ZString.initOwned - owned string" {
    const allocator = std.testing.allocator;

    var zstr = try ZString.initOwned(allocator, "hello");
    defer zstr.deinit();

    try std.testing.expectEqual(@as(usize, 5), zstr.length());
    try std.testing.expect(zstr.isOwned());
}

test "ZString.length - UTF-16 compliance" {
    // ASCII
    var ascii = ZString.init("hello");
    try std.testing.expectEqual(@as(usize, 5), ascii.length());

    // Unicode BMP
    var bmp = ZString.init("café");
    try std.testing.expectEqual(@as(usize, 4), bmp.length());

    // Emoji (surrogate pair)
    var emoji = ZString.init("😀");
    try std.testing.expectEqual(@as(usize, 2), emoji.length());

    // Mixed
    var mixed = ZString.init("hello😀world");
    try std.testing.expectEqual(@as(usize, 12), mixed.length()); // 5 + 2 + 5

    // Empty
    var empty = ZString.init("");
    try std.testing.expectEqual(@as(usize, 0), empty.length());
}

test "ZString.length - caching" {
    var zstr = ZString.init("hello😀");

    // First call computes and caches
    try std.testing.expectEqual(@as(usize, 7), zstr.length());
    try std.testing.expect(zstr.cached_utf16_length != null);

    // Second call uses cache
    try std.testing.expectEqual(@as(usize, 7), zstr.length());
}

test "ZString.isEmpty" {
    var empty = ZString.init("");
    try std.testing.expect(empty.isEmpty());

    var not_empty = ZString.init("a");
    try std.testing.expect(!not_empty.isEmpty());
}

test "ZString.isWellFormed" {
    var valid = ZString.init("hello😀");
    try std.testing.expect(valid.isWellFormed());

    // Invalid UTF-8
    const invalid_utf8 = [_]u8{ 0xFF, 0xFE, 0xFD };
    var invalid = ZString.init(&invalid_utf8);
    try std.testing.expect(!invalid.isWellFormed());
}

test "ZString.eql" {
    const str1 = ZString.init("hello");
    const str2 = ZString.init("hello");
    const str3 = ZString.init("world");

    try std.testing.expect(str1.eql(str2));
    try std.testing.expect(!str1.eql(str3));
}

test "ZString.clone" {
    const allocator = std.testing.allocator;

    const original = ZString.init("hello");
    var cloned = try original.clone(allocator);
    defer cloned.deinit();

    try std.testing.expect(original.eql(cloned));
    try std.testing.expect(cloned.isOwned());
    try std.testing.expect(!original.isOwned());
}
