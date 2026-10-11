const units = @import("../core/units.zig");
const std = @import("std");
const utf16 = @import("../core/utf16.zig");
const Allocator = std.mem.Allocator;

/// String.prototype.padStart(targetLength, padString)
/// Spec: https://tc39.es/ecma262/#sec-string.prototype.padstart
///
/// Pads the current string with another string (multiple times, if needed)
/// until the resulting string reaches the given length.
/// The padding is applied from the start of the current string.
///
/// Examples:
///   padStart("5", 3, "0") -> "005"
///   padStart("abc", 10, null) -> "       abc" (default space)
///   padStart("abc", 6, "123456") -> "123abc"
///   padStart("abc", 2, "0") -> "abc" (no change if already long enough)
pub fn padStart(allocator: Allocator, str: []const u8, targetLength: isize, padString: ?[]const u8) ![]u8 {
    if (targetLength <= 0) return allocator.dupe(u8, str);
    const target: usize = @intCast(targetLength);
    const length = utf16.lengthUtf16(str);
    const pad = padString orelse " ";
    if (length >= target or pad.len == 0) return allocator.dupe(u8, str);
    const pad_length = utf16.lengthUtf16(pad);
    if (pad_length == 0) return allocator.dupe(u8, str);
    const needed = target - length;
    const repeats = needed / pad_length;
    const partial = needed % pad_length;
    const multiplication = @mulWithOverflow(repeats, pad.len);
    if (multiplication[1] != 0) return error.OutOfMemory;
    const addition = @addWithOverflow(multiplication[0], str.len);
    if (addition[1] != 0 or (partial != 0 and addition[0] > std.math.maxInt(usize) - pad.len)) return error.OutOfMemory;
    var out: units.Builder = .{ .allocator = allocator };
    defer out.deinit();
    const valid_pad = std.unicode.utf8ValidateSlice(pad);
    const partial_bytes: usize = if (partial == 0) 0 else if (valid_pad) blk: {
        const boundary = utf16.utf16IndexToBytePos(pad, partial) catch unreachable;
        break :blk boundary.byte_index + (if (boundary.is_low_surrogate) @as(usize, 3) else 0);
    } else pad.len;
    try out.list.ensureTotalCapacityPrecise(allocator, addition[0] + partial_bytes);

    for (0..repeats) |_| {
        if (valid_pad) try out.list.appendSlice(allocator, pad) else try out.appendString(pad);
    }
    var cursor: units.Cursor = .{ .data = pad };
    for (0..partial) |_| try out.appendUnit(cursor.next().?);
    try out.appendString(str);
    return out.finish();
}

/// String.prototype.padEnd(targetLength, padString)
/// Spec: https://tc39.es/ecma262/#sec-string.prototype.padend
///
/// Pads the current string with another string (multiple times, if needed)
/// until the resulting string reaches the given length.
/// The padding is applied from the end of the current string.
///
/// Examples:
///   padEnd("5", 3, "0") -> "500"
///   padEnd("abc", 10, null) -> "abc       " (default space)
///   padEnd("abc", 6, "123456") -> "abc123"
///   padEnd("abc", 2, "0") -> "abc" (no change if already long enough)
pub fn padEnd(allocator: Allocator, str: []const u8, targetLength: isize, padString: ?[]const u8) ![]u8 {
    if (targetLength <= 0) return allocator.dupe(u8, str);
    const target: usize = @intCast(targetLength);
    const length = utf16.lengthUtf16(str);
    const pad = padString orelse " ";
    if (length >= target or pad.len == 0) return allocator.dupe(u8, str);
    const pad_length = utf16.lengthUtf16(pad);
    if (pad_length == 0) return allocator.dupe(u8, str);
    const needed = target - length;
    const repeats = needed / pad_length;
    const partial = needed % pad_length;
    const multiplication = @mulWithOverflow(repeats, pad.len);
    if (multiplication[1] != 0) return error.OutOfMemory;
    const addition = @addWithOverflow(multiplication[0], str.len);
    if (addition[1] != 0 or (partial != 0 and addition[0] > std.math.maxInt(usize) - pad.len)) return error.OutOfMemory;
    var out: units.Builder = .{ .allocator = allocator };
    defer out.deinit();
    const valid_pad = std.unicode.utf8ValidateSlice(pad);
    const partial_bytes: usize = if (partial == 0) 0 else if (valid_pad) blk: {
        const boundary = utf16.utf16IndexToBytePos(pad, partial) catch unreachable;
        break :blk boundary.byte_index + (if (boundary.is_low_surrogate) @as(usize, 3) else 0);
    } else pad.len;
    try out.list.ensureTotalCapacityPrecise(allocator, addition[0] + partial_bytes);
    try out.appendString(str);
    for (0..repeats) |_| {
        if (valid_pad) try out.list.appendSlice(allocator, pad) else try out.appendString(pad);
    }
    var cursor: units.Cursor = .{ .data = pad };
    for (0..partial) |_| try out.appendUnit(cursor.next().?);

    return out.finish();
}

// ============================================================================
// Tests
// ============================================================================

test "padStart - basic functionality" {
    const allocator = std.testing.allocator;

    // "5".padStart(3, "0") -> "005"
    const result1 = try padStart(allocator, "5", 3, "0");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("005", result1);

    // "abc".padStart(10) -> "       abc" (default space)
    const result2 = try padStart(allocator, "abc", 10, null);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("       abc", result2);

    // "abc".padStart(6, "123") -> "123abc"
    const result3 = try padStart(allocator, "abc", 6, "123");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("123abc", result3);
}

test "padStart - already long enough" {
    const allocator = std.testing.allocator;

    // "abc".padStart(2, "0") -> "abc"
    const result1 = try padStart(allocator, "abc", 2, "0");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("abc", result1);

    // "abc".padStart(3, "0") -> "abc"
    const result2 = try padStart(allocator, "abc", 3, "0");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("abc", result2);
}

test "padStart - multi-character pad" {
    const allocator = std.testing.allocator;

    // "abc".padStart(10, "foo") -> "foofoofabc"
    const result = try padStart(allocator, "abc", 10, "foo");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("foofoofabc", result);
}

test "padStart - partial pad" {
    const allocator = std.testing.allocator;

    // "abc".padStart(5, "12") -> "12abc" (partial "12")
    const result = try padStart(allocator, "abc", 5, "12");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("12abc", result);
}

test "padStart - empty string" {
    const allocator = std.testing.allocator;

    // "".padStart(3, "x") -> "xxx"
    const result = try padStart(allocator, "", 3, "x");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("xxx", result);
}

test "padEnd - basic functionality" {
    const allocator = std.testing.allocator;

    // "5".padEnd(3, "0") -> "500"
    const result1 = try padEnd(allocator, "5", 3, "0");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("500", result1);

    // "abc".padEnd(10) -> "abc       " (default space)
    const result2 = try padEnd(allocator, "abc", 10, null);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("abc       ", result2);

    // "abc".padEnd(6, "123") -> "abc123"
    const result3 = try padEnd(allocator, "abc", 6, "123");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("abc123", result3);
}

test "padEnd - already long enough" {
    const allocator = std.testing.allocator;

    // "abc".padEnd(2, "0") -> "abc"
    const result = try padEnd(allocator, "abc", 2, "0");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abc", result);
}

test "padEnd - multi-character pad" {
    const allocator = std.testing.allocator;

    // "abc".padEnd(10, "foo") -> "abcfoofoot"
    const result = try padEnd(allocator, "abc", 10, "foo");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abcfoofoof", result);
}

test "padEnd - partial pad" {
    const allocator = std.testing.allocator;

    // "abc".padEnd(5, "12") -> "abc12"
    const result = try padEnd(allocator, "abc", 5, "12");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abc12", result);
}

test "padEnd - empty string" {
    const allocator = std.testing.allocator;

    // "".padEnd(3, "x") -> "xxx"
    const result = try padEnd(allocator, "", 3, "x");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("xxx", result);
}
