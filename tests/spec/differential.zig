const std = @import("std");
const z = @import("zstring");
const A = std.testing.allocator;
const Op = enum { indexOf, lastIndexOf, includes, startsWith, endsWith, charCodeAt, codePointAt, slice, substring, padStart, padEnd, toLowerCase, toUpperCase, toWellFormed, replace, replaceAll, isWellFormed, at, normalize_error };
const Case = struct { op: Op, source: []const u8 = "", form: []const u8 = "", input: []u16, needle: []u16 = &.{}, position: isize = 0, end: ?isize = null, expected_number: ?i64 = null, expected_bool: ?bool = null, expected_units: ?[]u16 = null };

test "differential - deterministic ECMA-262 String fixtures from Node" {
    try runCorpus("data/string_oracle.json", 9000);
}

test "Test262 - typed assertions adapted from eight pinned official String tests" {
    try runCorpus("data/test262_oracle.json", 45);
}

fn runCorpus(comptime filename: []const u8, minimum: usize) !void {
    const parsed = try std.json.parseFromSlice([]Case, A, @embedFile(filename), .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value.len > minimum);
    for (parsed.value, 0..) |case, i| {
        var input = try z.ZString.fromCharCodeEcma(A, case.input);
        defer input.deinit();
        var needle = try z.ZString.fromCharCodeEcma(A, case.needle);
        defer needle.deinit();
        switch (case.op) {
            .at => {
                const actual = (try input.at(A, case.position)).?;
                defer A.free(actual);
                var expected = try z.ZString.fromCharCodeEcma(A, case.expected_units.?);
                defer expected.deinit();
                try std.testing.expect(expected.eqlSlice(actual));
            },
            .normalize_error => try std.testing.expectError(error.InvalidNormalizationForm, input.normalizeStrict(A, case.form)),
            .indexOf, .lastIndexOf => {
                const actual = if (case.op == .indexOf) input.indexOf(needle.data, case.position) else input.lastIndexOf(needle.data, case.position);
                try std.testing.expectEqual(case.expected_number.?, actual);
            },
            .includes, .startsWith, .endsWith, .isWellFormed => {
                const actual = switch (case.op) {
                    .includes => input.includes(needle.data, case.position),
                    .startsWith => input.startsWith(needle.data, case.position),
                    .endsWith => input.endsWith(needle.data, case.position),
                    .isWellFormed => input.isWellFormed(),
                    else => unreachable,
                };
                try std.testing.expectEqual(case.expected_bool.?, actual);
            },
            .charCodeAt, .codePointAt => {
                const actual: ?i64 = if (case.op == .charCodeAt) (if (input.charCodeAt(case.position)) |v| @as(i64, v) else null) else (if (input.codePointAt(case.position)) |v| @as(i64, v) else null);
                try std.testing.expectEqual(case.expected_number, actual);
            },
            else => {
                const actual = switch (case.op) {
                    .slice => try input.slice(A, case.position, case.end),
                    .substring => try input.substring(A, case.position, case.end),
                    .padStart => try input.padStart(A, case.position, needle.data),
                    .padEnd => try input.padEnd(A, case.position, needle.data),
                    .toLowerCase => try input.toLowerCase(A),
                    .toUpperCase => try input.toUpperCase(A),
                    .toWellFormed => try input.toWellFormed(A),
                    .replace => try input.replaceLiteral(A, needle.data, "[$&]"),
                    .replaceAll => try input.replaceAllLiteral(A, needle.data, "[$&]"),
                    else => unreachable,
                };
                defer A.free(actual);
                var expected = try z.ZString.fromCharCodeEcma(A, case.expected_units.?);
                defer expected.deinit();
                if (!expected.eqlSlice(actual)) std.debug.print("Differential case {d}, {s}\n", .{ i, @tagName(case.op) });
                try std.testing.expect(expected.eqlSlice(actual));
            },
        }
    }
}
