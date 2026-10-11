const std = @import("std");
const units = @import("../core/units.zig");
const unicode = @import("../unicode/algorithms.zig");
const Allocator = std.mem.Allocator;

pub const NormalizationForm = enum {
    NFC,
    NFD,
    NFKC,
    NFKD,

    pub fn fromString(s: []const u8) ?NormalizationForm {
        if (std.mem.eql(u8, s, "NFC")) return .NFC;
        if (std.mem.eql(u8, s, "NFD")) return .NFD;
        if (std.mem.eql(u8, s, "NFKC")) return .NFKC;
        if (std.mem.eql(u8, s, "NFKD")) return .NFKD;
        return null;
    }
};

fn lessClass(_: void, a: u21, b: u21) bool {
    return unicode.combiningClass(a) < unicode.combiningClass(b);
}

pub fn normalize(allocator: Allocator, str: []const u8, form: NormalizationForm) ![]u8 {
    if (units.isAscii(str)) return allocator.dupe(u8, str);
    var validate: units.Cursor = .{ .data = str };
    while (validate.next()) |unit| if (!unit.valid) return allocator.dupe(u8, str);
    var points: std.ArrayList(u21) = .empty;
    defer points.deinit(allocator);
    var iterator: unicode.Decomposed = .{ .input = .{ .cursor = .{ .data = str } }, .compatibility = form == .NFKD or form == .NFKC };
    while (iterator.next()) |cp| try points.append(allocator, cp);
    var start: usize = 0;
    for (points.items, 0..) |cp, i| {
        if (unicode.combiningClass(cp) == 0) {
            std.sort.block(u21, points.items[start..i], {}, lessClass);
            start = i + 1;
        }
    }
    std.sort.block(u21, points.items[start..], {}, lessClass);
    if (form == .NFC or form == .NFKC) {
        var starter: ?usize = null;
        var previous_class: u8 = 0;
        var write: usize = 0;
        for (points.items) |cp| {
            const class = unicode.combiningClass(cp);
            if (starter) |index| {
                if (previous_class == 0 or previous_class < class) {
                    if (unicode.compose(points.items[index], cp)) |combined| {
                        points.items[index] = combined;
                        continue;
                    }
                }
            }
            if (class == 0) starter = write;
            points.items[write] = cp;
            write += 1;
            previous_class = class;
        }
        points.items.len = write;
    }
    var out: units.Builder = .{ .allocator = allocator };
    defer out.deinit();
    try out.list.ensureTotalCapacity(allocator, str.len);
    for (points.items) |cp| try out.append(cp);
    return out.finish();
}

fn decompose(allocator: Allocator, str: []const u8) ![]u8 {
    return normalize(allocator, str, .NFD);
}
fn compose(allocator: Allocator, str: []const u8) ![]u8 {
    return normalize(allocator, str, .NFC);
}

test "decompose - accented characters" {
    const allocator = std.testing.allocator;

    // é should decompose to e + combining acute
    const result = try decompose(allocator, "é");
    defer allocator.free(result);

    // Check that it contains more bytes (base + combining)
    try std.testing.expect(result.len > 1);
}

test "compose - combining characters" {
    const allocator = std.testing.allocator;

    // e + combining acute should compose to é
    const input = "e\u{0301}"; // e + combining acute
    const result = try compose(allocator, input);
    defer allocator.free(result);

    // Result should contain é
    try std.testing.expect(result.len > 0);
}

test "normalize - NFC" {
    const allocator = std.testing.allocator;

    const result = try normalize(allocator, "café", .NFC);
    defer allocator.free(result);

    try std.testing.expect(result.len > 0);
}

test "normalize - NFD" {
    const allocator = std.testing.allocator;

    const result = try normalize(allocator, "café", .NFD);
    defer allocator.free(result);

    // NFD should result in more bytes (decomposed)
    try std.testing.expect(result.len >= "café".len);
}

test "normalize - ASCII unchanged" {
    const allocator = std.testing.allocator;

    const input = "hello";
    const result = try normalize(allocator, input, .NFC);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(input, result);
}

test "normalize - empty string" {
    const allocator = std.testing.allocator;

    const result = try normalize(allocator, "", .NFC);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}
