const std = @import("std");
const units = @import("../core/units.zig");
const unicode = @import("../unicode/algorithms.zig");
const data = @import("../unicode/data.zig");
const Allocator = std.mem.Allocator;

pub fn toLowerCase(allocator: Allocator, str: []const u8) ![]u8 {
    return convert(allocator, str, false);
}
pub fn toUpperCase(allocator: Allocator, str: []const u8) ![]u8 {
    return convert(allocator, str, true);
}

/// ECMA-262 basic profile: fixed root host locale. Optional parameter positions
/// remain reserved for ECMA-402; this API does not advertise ECMA-402 support.
pub fn toLocaleLowerCase(allocator: Allocator, str: []const u8, _locale: ?[]const u8) ![]u8 {
    _ = _locale;
    return toLowerCase(allocator, str);
}
pub fn toLocaleUpperCase(allocator: Allocator, str: []const u8, _locale: ?[]const u8) ![]u8 {
    _ = _locale;
    return toUpperCase(allocator, str);
}

fn followingCased(cursor: units.Cursor) bool {
    var iterator: units.Iterator = .{ .cursor = cursor };
    while (iterator.next()) |cp| {
        if (unicode.isCaseIgnorable(cp)) continue;
        return unicode.isCased(cp);
    }
    return false;
}

fn convert(allocator: Allocator, str: []const u8, upper: bool) ![]u8 {
    if (units.isAscii(str)) {
        const out = try allocator.dupe(u8, str);
        for (out) |*byte| byte.* = if (upper) std.ascii.toUpper(byte.*) else std.ascii.toLower(byte.*);
        return out;
    }
    var out: units.Builder = .{ .allocator = allocator };
    defer out.deinit();
    try out.list.ensureTotalCapacity(allocator, str.len);
    var cursor: units.Cursor = .{ .data = str };
    var preceded_cased = false;
    while (cursor.next()) |unit| {
        if (!unit.valid) {
            try out.appendUnit(unit);
            preceded_cased = false;
            continue;
        }
        var cp: u21 = unit.value;
        if (cp >= 0xd800 and cp <= 0xdbff) {
            var peek = cursor;
            if (peek.next()) |low| {
                if (low.valid and low.value >= 0xdc00 and low.value <= 0xdfff) {
                    cp = 0x10000 + ((cp - 0xd800) << 10) + low.value - 0xdc00;
                    cursor = peek;
                }
            }
        }
        if (!upper and cp == 0x03a3 and preceded_cased and !followingCased(cursor)) {
            try out.append(0x03c2);
        } else if (unicode.lookup(data.Case, &data.cases, cp)) |mapping| {
            const sequence = if (upper) mapping.upper[0..mapping.upper_len] else mapping.lower[0..mapping.lower_len];
            for (sequence) |mapped| try out.append(mapped);
        } else try out.append(cp);
        if (!unicode.isCaseIgnorable(cp)) preceded_cased = unicode.isCased(cp);
    }
    return out.finish();
}

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
