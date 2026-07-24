const std = @import("std");
const utf16 = @import("../core/utf16.zig");
const zregex = @import("zregex");

const Allocator = std.mem.Allocator;

/// String.prototype.search(regexp)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.search
///
/// Executes a search for a match between a regular expression and this string,
/// returning the index of the first match in UTF-16 code units, or -1 if not found.
///
/// Examples:
///   search("hello world", "wo") -> 6
///   search("hello world", "\\d+") -> -1
///   search("Price: $100", "\\d+") -> 8
pub fn search(allocator: Allocator, str: []const u8, pattern: []const u8) !isize {
    // Compile the regex pattern
    var re = zregex.Regex.compile(allocator, pattern) catch {
        // If compilation fails, return -1 (no match)
        return -1;
    };
    defer re.deinit();

    // Find the first match
    const match_result = re.find(str) catch return -1;
    if (match_result) |m| {
        defer m.deinit();
        // Convert byte offset to UTF-16 index
        const utf16_index = utf16.byteIndexToUtf16(str, m.start) catch return -1;
        return @intCast(utf16_index);
    }

    return -1; // Not found
}

/// Match result structure returned by match() and matchAll()
pub const MatchArray = struct {
    /// The full matched string
    match: []const u8,
    /// Captured groups (null if not captured)
    groups: []?[]const u8,
    /// Index where the match was found (UTF-16 code units)
    index: usize,
    /// The original input string
    input: []const u8,
    /// Allocator for freeing memory
    allocator: Allocator,

    pub fn deinit(self: MatchArray) void {
        self.allocator.free(self.match);
        for (self.groups) |group| {
            if (group) |g| {
                self.allocator.free(g);
            }
        }
        self.allocator.free(self.groups);
    }
};

/// String.prototype.match(regexp)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.match
///
/// Retrieves the matches when matching a string against a regular expression.
/// Returns an array of matches, or null if no match is found.
///
/// Examples:
///   match("hello world", "l+") -> MatchArray with "ll"
///   match("Price: $100", "\\d+") -> MatchArray with "100"
pub fn match(allocator: Allocator, str: []const u8, pattern: []const u8) !?MatchArray {
    // Compile the regex pattern
    var re = zregex.Regex.compile(allocator, pattern) catch return null;
    defer re.deinit();

    // Find the first match
    const match_result = re.find(str) catch return null;
    if (match_result) |m| {
        defer m.deinit();

        // Get the matched string
        const matched_str = m.group(str);
        const matched_copy = try allocator.dupe(u8, matched_str);

        // Extract capture groups
        var groups: std.ArrayList(?[]const u8) = .empty;
        defer groups.deinit(allocator);

        // Try to get up to 16 capture groups (zregex's limit)
        var i: usize = 1;
        while (i < 16) : (i += 1) {
            if (m.getCapture(i, str)) |capture| {
                const capture_copy = try allocator.dupe(u8, capture);
                try groups.append(allocator, capture_copy);
            } else {
                try groups.append(allocator, null);
            }
        }

        // Convert start position to UTF-16 index
        const utf16_index = utf16.byteIndexToUtf16(str, m.start) catch 0;

        return MatchArray{
            .match = matched_copy,
            .groups = try groups.toOwnedSlice(allocator),
            .index = utf16_index,
            .input = str,
            .allocator = allocator,
        };
    }

    return null;
}

/// String.prototype.matchAll(regexp)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.matchall
///
/// Returns an iterator of all results matching a string against a regular expression,
/// including capturing groups.
///
/// Examples:
///   matchAll("test test", "t") -> Array of 4 matches
pub fn matchAll(allocator: Allocator, str: []const u8, pattern: []const u8) ![]MatchArray {
    // Compile the regex pattern
    var re = zregex.Regex.compile(allocator, pattern) catch {
        // If compilation fails, return empty array
        return try allocator.alloc(MatchArray, 0);
    };
    defer re.deinit();

    // Find all matches
    var match_results = re.findAll(str) catch {
        return try allocator.alloc(MatchArray, 0);
    };
    defer {
        for (match_results.items) |m| {
            m.deinit();
        }
        match_results.deinit(allocator);
    }

    // Convert to MatchArray format
    var matches: std.ArrayList(MatchArray) = .empty;
    defer matches.deinit(allocator);

    for (match_results.items) |m| {
        // Get the matched string
        const matched_str = m.group(str);
        const matched_copy = try allocator.dupe(u8, matched_str);

        // Extract capture groups
        var groups: std.ArrayList(?[]const u8) = .empty;
        defer groups.deinit(allocator);

        var i: usize = 1;
        while (i < 16) : (i += 1) {
            if (m.getCapture(i, str)) |capture| {
                const capture_copy = try allocator.dupe(u8, capture);
                try groups.append(allocator, capture_copy);
            } else {
                try groups.append(allocator, null);
            }
        }

        // Convert start position to UTF-16 index
        const utf16_index = utf16.byteIndexToUtf16(str, m.start) catch 0;

        try matches.append(allocator, MatchArray{
            .match = matched_copy,
            .groups = try groups.toOwnedSlice(allocator),
            .index = utf16_index,
            .input = str,
            .allocator = allocator,
        });
    }

    return try matches.toOwnedSlice(allocator);
}

/// Free the result of matchAll
pub fn freeMatchAll(allocator: Allocator, matches: []MatchArray) void {
    for (matches) |match_array| {
        match_array.deinit();
    }
    allocator.free(matches);
}

/// String.prototype.replace(searchValue, replaceValue)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.replace
///
/// Returns a new string with the first match of a pattern replaced by a replacement.
/// The pattern can be a string or a RegExp.
///
/// Examples:
///   replace("hello world", "world", "zig") -> "hello zig"
///   replace("test test", "t", "T") -> "Test test" (only first)
pub fn replace(allocator: Allocator, str: []const u8, pattern: []const u8, replacement: []const u8) ![]const u8 {
    // Try to compile as regex first
    var is_regex = true;
    var re = zregex.Regex.compile(allocator, pattern) catch blk: {
        is_regex = false;
        break :blk undefined;
    };
    defer if (is_regex) re.deinit();

    if (is_regex) {
        // Find the first match
        const match_result = re.find(str) catch {
            // No match, return copy of original
            return try allocator.dupe(u8, str);
        };

        if (match_result) |m| {
            defer m.deinit();

            // Build the result string: before + replacement + after
            var result: std.ArrayList(u8) = .empty;
            defer result.deinit(allocator);

            // Add everything before the match
            try result.appendSlice(allocator,str[0..m.start]);
            // Add replacement
            try result.appendSlice(allocator,replacement);
            // Add everything after the match
            try result.appendSlice(allocator,str[m.end..]);

            return try result.toOwnedSlice(allocator);
        }
    }

    // Fallback to literal string replacement
    if (std.mem.indexOf(u8, str, pattern)) |pos| {
        var result: std.ArrayList(u8) = .empty;
        defer result.deinit(allocator);

        try result.appendSlice(allocator,str[0..pos]);
        try result.appendSlice(allocator,replacement);
        try result.appendSlice(allocator,str[pos + pattern.len ..]);

        return try result.toOwnedSlice(allocator);
    }

    // No match, return copy of original
    return try allocator.dupe(u8, str);
}

/// String.prototype.replaceAll(searchValue, replaceValue)
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.replaceall
///
/// Returns a new string with all matches of a pattern replaced by a replacement.
/// The pattern can be a string or a RegExp.
///
/// Examples:
///   replaceAll("test test", "t", "T") -> "TesT TesT"
///   replaceAll("hello world", "l", "L") -> "heLLo worLd"
pub fn replaceAll(allocator: Allocator, str: []const u8, pattern: []const u8, replacement: []const u8) ![]const u8 {
    // Try to compile as regex first
    var is_regex = true;
    var re = zregex.Regex.compile(allocator, pattern) catch blk: {
        is_regex = false;
        break :blk undefined;
    };
    defer if (is_regex) re.deinit();

    if (is_regex) {
        // Find all matches
        var match_results = re.findAll(str) catch {
            // No matches, return copy of original
            return try allocator.dupe(u8, str);
        };
        defer {
            for (match_results.items) |m| {
                m.deinit();
            }
            match_results.deinit(allocator);
        }

        if (match_results.items.len == 0) {
            return try allocator.dupe(u8, str);
        }

        // Build result by replacing all matches
        var result: std.ArrayList(u8) = .empty;
        defer result.deinit(allocator);

        var last_end: usize = 0;
        for (match_results.items) |m| {
            // Add everything between last match and this match
            try result.appendSlice(allocator,str[last_end..m.start]);
            // Add replacement
            try result.appendSlice(allocator,replacement);
            last_end = m.end;
        }
        // Add remaining string
        try result.appendSlice(allocator,str[last_end..]);

        return try result.toOwnedSlice(allocator);
    }

    // Fallback to literal string replacement
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var pos: usize = 0;
    while (pos < str.len) {
        if (std.mem.indexOf(u8, str[pos..], pattern)) |offset| {
            const absolute_pos = pos + offset;
            // Add everything up to the match
            try result.appendSlice(allocator,str[pos..absolute_pos]);
            // Add replacement
            try result.appendSlice(allocator,replacement);
            // Move past the match
            pos = absolute_pos + pattern.len;
        } else {
            // No more matches, add remaining string
            try result.appendSlice(allocator,str[pos..]);
            break;
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// String.prototype.split(regexp, limit) -- regex-separator sibling of
/// split.zig's split() (Zig has no function overloading, so a regex
/// separator can't share that name; same "takes a raw pattern, compiles
/// it internally" convention as search/match/matchAll/replace/replaceAll
/// above).
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.split
///
/// Splits `str` wherever `pattern` matches, discarding the matched
/// separators. An unparseable pattern or a pattern with no matches
/// behaves like split(str, null, limit) -- the whole string, unsplit.
///
/// Narrowing: a pattern that can match the empty string (e.g. "x*") is
/// not given the exact ECMA-262 zero-width-match handling real JS uses
/// (skip-and-advance-by-one instead of an empty split); each empty match
/// still produces an empty piece between it and the previous split point.
///
/// Examples:
///   splitRegex("a1b2c3", "[0-9]+", null) -> ["a", "b", "c"]
///   splitRegex("one, two,three", ",\\s*", null) -> ["one", "two", "three"]
pub fn splitRegex(allocator: Allocator, str: []const u8, pattern: []const u8, limit: ?usize) ![][]u8 {
    var result: std.ArrayList([]u8) = .empty;
    errdefer {
        for (result.items) |item| allocator.free(item);
        result.deinit(allocator);
    }

    if (limit != null and limit.? == 0) {
        return result.toOwnedSlice(allocator);
    }

    var re = zregex.Regex.compile(allocator, pattern) catch {
        try result.append(allocator, try allocator.dupe(u8, str));
        return result.toOwnedSlice(allocator);
    };
    defer re.deinit();

    var matches = re.findAll(str) catch {
        try result.append(allocator, try allocator.dupe(u8, str));
        return result.toOwnedSlice(allocator);
    };
    defer {
        for (matches.items) |m| m.deinit();
        matches.deinit(allocator);
    }

    var last_end: usize = 0;
    for (matches.items) |m| {
        if (limit) |lim| {
            if (result.items.len >= lim) break;
        }
        try result.append(allocator, try allocator.dupe(u8, str[last_end..m.start]));
        last_end = m.end;
    }
    if (limit == null or result.items.len < limit.?) {
        try result.append(allocator, try allocator.dupe(u8, str[last_end..]));
    }

    return result.toOwnedSlice(allocator);
}

// =============================================================================
// Tests
// =============================================================================

test "search: basic pattern" {
    const result = try search(std.testing.allocator, "hello world", "world");
    try std.testing.expectEqual(@as(isize, 6), result);
}

test "search: not found" {
    const result = try search(std.testing.allocator, "hello world", "xyz");
    try std.testing.expectEqual(@as(isize, -1), result);
}

test "search: regex pattern" {
    const result = try search(std.testing.allocator, "Price: $100", "[0-9]+");
    try std.testing.expectEqual(@as(isize, 8), result);
}

test "match: basic pattern" {
    const result = try match(std.testing.allocator, "hello world", "world");
    try std.testing.expect(result != null);
    defer if (result) |r| r.deinit();

    if (result) |r| {
        try std.testing.expectEqualStrings("world", r.match);
        try std.testing.expectEqual(@as(usize, 6), r.index);
    }
}

test "match: not found" {
    const result = try match(std.testing.allocator, "hello world", "xyz");
    try std.testing.expect(result == null);
}

test "matchAll: multiple matches" {
    const result = try matchAll(std.testing.allocator, "test test test", "test");
    defer freeMatchAll(std.testing.allocator, result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
}

test "replace: basic replacement" {
    const result = try replace(std.testing.allocator, "hello world", "world", "zig");
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("hello zig", result);
}

test "replace: only first match" {
    const result = try replace(std.testing.allocator, "test test", "test", "TEST");
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("TEST test", result);
}

test "replaceAll: all matches" {
    const result = try replaceAll(std.testing.allocator, "test test test", "test", "TEST");
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("TEST TEST TEST", result);
}

test "replaceAll: no match" {
    const result = try replaceAll(std.testing.allocator, "hello world", "xyz", "ABC");
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("hello world", result);
}

test "splitRegex: digits as separator" {
    // Matches real JS: 'a1b2c3'.split(/[0-9]+/) -> ["a","b","c",""] --
    // the string ends right after the last match, so there's a real
    // (empty) segment between that match and the end of the string.
    const result = try splitRegex(std.testing.allocator, "a1b2c3", "[0-9]+", null);
    defer {
        for (result) |item| std.testing.allocator.free(item);
        std.testing.allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("b", result[1]);
    try std.testing.expectEqualStrings("c", result[2]);
    try std.testing.expectEqualStrings("", result[3]);
}

test "splitRegex: comma with optional trailing spaces" {
    const result = try splitRegex(std.testing.allocator, "one, two,three", ",\\s*", null);
    defer {
        for (result) |item| std.testing.allocator.free(item);
        std.testing.allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("one", result[0]);
    try std.testing.expectEqualStrings("two", result[1]);
    try std.testing.expectEqualStrings("three", result[2]);
}

test "splitRegex: no match returns the whole string" {
    const result = try splitRegex(std.testing.allocator, "hello", "[0-9]+", null);
    defer {
        for (result) |item| std.testing.allocator.free(item);
        std.testing.allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqualStrings("hello", result[0]);
}

test "splitRegex: respects limit" {
    const result = try splitRegex(std.testing.allocator, "a1b2c3d4e", "[0-9]", 2);
    defer {
        for (result) |item| std.testing.allocator.free(item);
        std.testing.allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqualStrings("a", result[0]);
    try std.testing.expectEqualStrings("b", result[1]);
}

test "splitRegex: limit zero returns an empty array" {
    const result = try splitRegex(std.testing.allocator, "a1b2c3", "[0-9]+", 0);
    defer {
        for (result) |item| std.testing.allocator.free(item);
        std.testing.allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "splitRegex: invalid pattern falls back to the whole string" {
    const result = try splitRegex(std.testing.allocator, "hello", "[", null);
    defer {
        for (result) |item| std.testing.allocator.free(item);
        std.testing.allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqualStrings("hello", result[0]);
}
