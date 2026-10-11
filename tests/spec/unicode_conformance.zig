const std = @import("std");
const z = @import("zstring");
const allocator = std.testing.allocator;

fn decode(sequence: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var words = std.mem.tokenizeAny(u8, sequence, " \t\r");
    while (words.next()) |word| {
        const cp = try std.fmt.parseInt(u21, word, 16);
        var buffer: [4]u8 = undefined;
        const n = try std.unicode.utf8Encode(cp, &buffer);
        try out.appendSlice(allocator, buffer[0..n]);
    }
    return out.toOwnedSlice(allocator);
}

test "Unicode NormalizationTest - all official records and four forms" {
    const corpus = @embedFile("data/NormalizationTest.txt");
    var lines = std.mem.splitScalar(u8, corpus, '\n');
    var records: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '#' or line[0] == '@') continue;
        var fields = std.mem.splitScalar(u8, line, ';');
        var columns: [5][]u8 = undefined;
        var count: usize = 0;
        defer for (columns[0..count]) |column| allocator.free(column);
        for (&columns) |*column| {
            column.* = try decode(fields.next().?);
            count += 1;
        }
        const forms = [_][]const u8{ "NFC", "NFD", "NFKC", "NFKD" };
        const targets = [_][5]usize{ .{ 1, 1, 1, 3, 3 }, .{ 2, 2, 2, 4, 4 }, .{ 3, 3, 3, 3, 3 }, .{ 4, 4, 4, 4, 4 } };
        for (forms, targets) |form, target| {
            for (columns, target) |input, index| {
                const actual = try z.utility.normalizeStrict(allocator, input, form);
                defer allocator.free(actual);
                if (!std.mem.eql(u8, columns[index], actual)) std.debug.print("Normalization record {d}, form {s}: {s}\n", .{ records, form, line });
                try std.testing.expectEqualStrings(columns[index], actual);
            }
        }
        records += 1;
    }
    try std.testing.expect(records > 19000);
}

fn checkCase(input: []const u8, expected_lower: []const u8, expected_upper: []const u8) !void {
    const lower = try z.case.toLowerCase(allocator, input);
    defer allocator.free(lower);
    const upper = try z.case.toUpperCase(allocator, input);
    defer allocator.free(upper);
    try std.testing.expectEqualStrings(expected_lower, lower);
    try std.testing.expectEqualStrings(expected_upper, upper);
}

test "Unicode case mappings - official UnicodeData and unconditional SpecialCasing" {
    var special = std.AutoHashMap(u21, void).init(allocator);
    defer special.deinit();
    var lines = std.mem.splitScalar(u8, @embedFile("data/SpecialCasing.txt"), '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw[0 .. std.mem.indexOfScalar(u8, raw, '#') orelse raw.len], " \r\t");
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, ';');
        const cp_field = std.mem.trim(u8, fields.next().?, " \t");
        const lower_field = fields.next().?;
        _ = fields.next(); // Title case is not a String operation.
        const upper_field = fields.next().?;
        if (std.mem.trim(u8, fields.next().?, " \r\t").len != 0) continue;
        const input = try decode(cp_field);
        defer allocator.free(input);
        const lower = try decode(lower_field);
        defer allocator.free(lower);
        const upper = try decode(upper_field);
        defer allocator.free(upper);
        try checkCase(input, lower, upper);
        try special.put(try std.fmt.parseInt(u21, cp_field, 16), {});
    }
    lines = std.mem.splitScalar(u8, @embedFile("data/UnicodeData.txt"), '\n');
    var records: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, ';');
        var columns: [15][]const u8 = undefined;
        for (&columns) |*column| column.* = fields.next().?;
        const cp = try std.fmt.parseInt(u21, columns[0], 16);
        if (special.contains(cp) or (columns[12].len == 0 and columns[13].len == 0)) continue;
        const input = try decode(columns[0]);
        defer allocator.free(input);
        const lower = try decode(if (columns[13].len != 0) columns[13] else columns[0]);
        defer allocator.free(lower);
        const upper = try decode(if (columns[12].len != 0) columns[12] else columns[0]);
        defer allocator.free(upper);
        try checkCase(input, lower, upper);
        records += 1;
    }
    try std.testing.expect(records > 2800);
}
