const std = @import("std");
const utf16 = @import("../core/utf16.zig");
const Allocator = std.mem.Allocator;

/// String.prototype.split(separator, limit)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.split
///
/// Splits a String object into an array of strings by separating the string
/// into substrings, using a specified separator string to determine where
/// to make each split.
///
/// Examples:
///   split("a,b,c", ",", null) -> ["a", "b", "c"]
///   split("hello", "", null) -> ["h", "e", "l", "l", "o"]
///   split("a,b,c", ",", 2) -> ["a", "b"]
///   split("test", null, null) -> ["test"]
///
/// Returns an array of strings. The caller is responsible for freeing both
/// the array itself and each individual string in the array.
pub fn split(allocator: Allocator, str: []const u8, separator: ?[]const u8, limit: ?usize) ![][]u8 {
    var result = std.ArrayList([]u8){};
    errdefer {
        for (result.items) |item| {
            allocator.free(item);
        }
        result.deinit(allocator);
    }

    // If separator is null, return array with whole string
    if (separator == null) {
        const copy = try allocator.dupe(u8, str);
        try result.append(allocator, copy);
        return result.toOwnedSlice(allocator);
    }

    const sep = separator.?;

    // If limit is 0, return empty array
    if (limit != null and limit.? == 0) {
        return result.toOwnedSlice(allocator);
    }

    // If string is empty
    if (str.len == 0) {
        if (sep.len == 0) {
            // "".split("") -> []
            return result.toOwnedSlice(allocator);
        } else {
            // "".split("x") -> [""]
            const empty = try allocator.alloc(u8, 0);
            try result.append(allocator, empty);
            return result.toOwnedSlice(allocator);
        }
    }

    // If separator is empty, split into individual UTF-16 code units
    if (sep.len == 0) {
        var i: usize = 0;
        while (i < str.len) {
            if (limit) |lim| {
                if (result.items.len >= lim) break;
            }

            const cp_len = std.unicode.utf8ByteSequenceLength(str[i]) catch break;
            if (i + cp_len > str.len) break;

            const char = try allocator.dupe(u8, str[i .. i + cp_len]);
            try result.append(allocator, char);

            i += cp_len;
        }
        return result.toOwnedSlice(allocator);
    }

    // Regular split with separator
    var start_pos: usize = 0;
    var search_pos: usize = 0;

    while (search_pos <= str.len) {
        // Check if we've reached the limit
        if (limit) |lim| {
            if (result.items.len >= lim) break;
        }

        // Look for separator at current position
        if (search_pos + sep.len <= str.len and
            std.mem.eql(u8, str[search_pos .. search_pos + sep.len], sep))
        {
            // Found separator - add substring before it
            const substring = try allocator.dupe(u8, str[start_pos..search_pos]);
            try result.append(allocator, substring);

            // Move past the separator
            search_pos += sep.len;
            start_pos = search_pos;
        } else {
            search_pos += 1;
        }
    }

    // Add remaining substring if we haven't hit the limit
    if (limit == null or result.items.len < limit.?) {
        const substring = try allocator.dupe(u8, str[start_pos..]);
        try result.append(allocator, substring);
    }

    return result.toOwnedSlice(allocator);
}

/// Helper function to free the result of split()
pub fn freeSplitResult(allocator: Allocator, result: [][]u8) void {
    for (result) |item| {
        allocator.free(item);
    }
    allocator.free(result);
}

// ============================================================================
// Tests
// ============================================================================

test "split - basic functionality" {
    const allocator = std.testing.allocator;

    // "a,b,c".split(",") -> ["a", "b", "c"]
    const result1 = try split(allocator, "a,b,c", ",", null);
    defer freeSplitResult(allocator, result1);
    try std.testing.expectEqual(@as(usize, 3), result1.len);
    try std.testing.expectEqualStrings("a", result1[0]);
    try std.testing.expectEqualStrings("b", result1[1]);
    try std.testing.expectEqualStrings("c", result1[2]);

    // "hello world".split(" ") -> ["hello", "world"]
    const result2 = try split(allocator, "hello world", " ", null);
    defer freeSplitResult(allocator, result2);
    try std.testing.expectEqual(@as(usize, 2), result2.len);
    try std.testing.expectEqualStrings("hello", result2[0]);
    try std.testing.expectEqualStrings("world", result2[1]);
}

test "split - empty separator" {
    const allocator = std.testing.allocator;

    // "hello".split("") -> ["h", "e", "l", "l", "o"]
    const result = try split(allocator, "hello", "", null);
    defer freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 5), result.len);
    try std.testing.expectEqualStrings("h", result[0]);
    try std.testing.expectEqualStrings("e", result[1]);
    try std.testing.expectEqualStrings("l", result[2]);
    try std.testing.expectEqualStrings("l", result[3]);
    try std.testing.expectEqualStrings("o", result[4]);
}

test "split - null separator" {
    const allocator = std.testing.allocator;

    // "hello".split(undefined) -> ["hello"]
    const result = try split(allocator, "hello", null, null);
    defer freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqualStrings("hello", result[0]);
}

test "split - with limit" {
    const allocator = std.testing.allocator;

    // "a,b,c,d".split(",", 2) -> ["a", "b"]
    const result1 = try split(allocator, "a,b,c,d", ",", 2);
    defer freeSplitResult(allocator, result1);
    try std.testing.expectEqual(@as(usize, 2), result1.len);
    try std.testing.expectEqualStrings("a", result1[0]);
    try std.testing.expectEqualStrings("b", result1[1]);

    // "hello".split("", 3) -> ["h", "e", "l"]
    const result2 = try split(allocator, "hello", "", 3);
    defer freeSplitResult(allocator, result2);
    try std.testing.expectEqual(@as(usize, 3), result2.len);
    try std.testing.expectEqualStrings("h", result2[0]);
    try std.testing.expectEqualStrings("e", result2[1]);
    try std.testing.expectEqualStrings("l", result2[2]);
}

test "split - limit zero" {
    const allocator = std.testing.allocator;

    // "a,b,c".split(",", 0) -> []
    const result = try split(allocator, "a,b,c", ",", 0);
    defer freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "split - separator not found" {
    const allocator = std.testing.allocator;

    // "hello".split(",") -> ["hello"]
    const result = try split(allocator, "hello", ",", null);
    defer freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqualStrings("hello", result[0]);
}

test "split - empty string" {
    const allocator = std.testing.allocator;

    // "".split(",") -> [""]
    const result1 = try split(allocator, "", ",", null);
    defer freeSplitResult(allocator, result1);
    try std.testing.expectEqual(@as(usize, 1), result1.len);
    try std.testing.expectEqualStrings("", result1[0]);

    // "".split("") -> []
    const result2 = try split(allocator, "", "", null);
    defer freeSplitResult(allocator, result2);
    try std.testing.expectEqual(@as(usize, 0), result2.len);
}

test "split - separator at start" {
    const allocator = std.testing.allocator;

    // ",a,b".split(",") -> ["", "a", "b"]
    const result = try split(allocator, ",a,b", ",", null);
    defer freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("", result[0]);
    try std.testing.expectEqualStrings("a", result[1]);
    try std.testing.expectEqualStrings("b", result[2]);
}

test "split - separator at end" {
    const allocator = std.testing.allocator;

    // "a,b,".split(",") -> ["a", "b", ""]
    const result = try split(allocator, "a,b,", ",", null);
    defer freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("b", result[1]);
    try std.testing.expectEqualStrings("", result[2]);
}

test "split - consecutive separators" {
    const allocator = std.testing.allocator;

    // "a,,b".split(",") -> ["a", "", "b"]
    const result = try split(allocator, "a,,b", ",", null);
    defer freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("", result[1]);
    try std.testing.expectEqualStrings("b", result[2]);
}

test "split - multi-character separator" {
    const allocator = std.testing.allocator;

    // "a::b::c".split("::") -> ["a", "b", "c"]
    const result = try split(allocator, "a::b::c", "::", null);
    defer freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("b", result[1]);
    try std.testing.expectEqualStrings("c", result[2]);
}

test "split - Unicode characters" {
    const allocator = std.testing.allocator;

    // "café,thé".split(",") -> ["café", "thé"]
    const result = try split(allocator, "café,thé", ",", null);
    defer freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqualStrings("café", result[0]);
    try std.testing.expectEqualStrings("thé", result[1]);
}

test "split - Emoji with empty separator" {
    const allocator = std.testing.allocator;

    // "a😀b".split("") -> ["a", "😀", "b"]
    const result = try split(allocator, "a😀b", "", null);
    defer freeSplitResult(allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("😀", result[1]);
    try std.testing.expectEqualStrings("b", result[2]);
}
