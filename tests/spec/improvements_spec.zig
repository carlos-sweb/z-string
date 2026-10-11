const std = @import("std");
const z = @import("zstring");
const A = std.testing.allocator;

fn expectOwned(expected: []const u8, actual: []u8) !void {
    defer A.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

test "regression - UTF-16 search boundaries and integer extremes" {
    try std.testing.expectEqual(@as(isize, 0), z.search.lastIndexOf("abc", "a", -1));
    try std.testing.expectEqual(@as(isize, -1), z.search.indexOf("😀", "😀", 1));
    try std.testing.expect(!z.search.startsWith("😀", "😀", 1));
    const high = "\xed\xa0\xbd";
    const low = "\xed\xb8\x80";
    try std.testing.expect(z.search.endsWith("😀", high, 1));
    try std.testing.expectEqual(@as(isize, 1), z.search.indexOf("😀", low, null));
    try std.testing.expect(z.search.includes("😀", high, null));
    try std.testing.expectEqual(@as(?[]u8, null), try z.access.at(A, "abc", std.math.minInt(isize)));
}

test "regression - padding and split use UTF-16 units" {
    try expectOwned("\xed\xa0\xbdx", try z.padding.padStart(A, "x", 2, "😀"));
    try expectOwned("x\xed\xa0\xbd", try z.padding.padEnd(A, "x", 2, "😀"));
    const zero = try z.split.split(A, "abc", null, 0);
    defer z.split.freeSplitResult(A, zero);
    try std.testing.expectEqual(@as(usize, 0), zero.len);
    const halves = try z.split.split(A, "😀", "\xed\xa0\xbd", null);
    defer z.split.freeSplitResult(A, halves);
    try std.testing.expectEqual(@as(usize, 2), halves.len);
    try std.testing.expectEqualStrings("", halves[0]);
    try std.testing.expectEqualStrings("\xed\xb8\x80", halves[1]);
}

test "regression - Unicode full case conversion and final sigma" {
    try expectOwned("i\u{0307}", try z.case.toLowerCase(A, "İ"));
    try expectOwned("ος", try z.case.toLowerCase(A, "ΟΣ"));
    try expectOwned("οσα", try z.case.toLowerCase(A, "ΟΣΑ"));
    try expectOwned("SS", try z.case.toUpperCase(A, "ß"));
    try expectOwned("ŸΣFFI", try z.case.toUpperCase(A, "ÿςﬃ"));
    try expectOwned("𐐨", try z.case.toLowerCase(A, "𐐀"));
    try expectOwned("\xed\xa0\x80hello", try z.case.toLowerCase(A, "\xed\xa0\x80HELLO"));
}

test "regression - normalization forms, Hangul and isolated surrogates" {
    try expectOwned("é", try z.utility.normalize(A, "é", "NFC"));
    try expectOwned("é", try z.utility.normalize(A, "e\u{0301}", "NFC"));
    try expectOwned("fi", try z.utility.normalize(A, "ﬁ", "NFKD"));
    try expectOwned("가", try z.utility.normalize(A, "가", "NFD"));
    try expectOwned("가", try z.utility.normalize(A, "가", "NFC"));
    try expectOwned("\xed\xa0\x80é", try z.utility.normalize(A, "\xed\xa0\x80e\u{0301}", "NFC"));
    try expectOwned("abc", try z.utility.normalize(A, "abc", "BAD"));
    try std.testing.expectError(error.InvalidNormalizationForm, z.utility.normalizeStrict(A, "abc", "BAD"));
}

test "regression - WTF-8 pairing, equality, repair and trimming" {
    const pair = "\xed\xa0\xbd\xed\xb8\x80";
    const str = z.ZString.init(pair);
    try std.testing.expect(str.eql(z.ZString.init("😀")));
    try std.testing.expect(str.isWellFormed());
    try std.testing.expectEqual(@as(?u21, 0x1f600), str.codePointAt(0));
    try expectOwned("😀", try str.toWellFormed(A));
    try expectOwned("�", try z.ZString.init("\xed\xa0\x80").toWellFormed(A));
    try expectOwned("\xed\xa0\x80", try z.trimming.trimStart(A, " \xed\xa0\x80"));
    try expectOwned("\xed\xa0\x80", try z.trimming.trimEnd(A, "\xed\xa0\x80 "));
    try expectOwned("\xed\xa0\x80", try z.trimming.trim(A, " \xed\xa0\x80 "));
}

test "regression - canonical comparison and construction capabilities" {
    try std.testing.expectEqual(@as(isize, 0), z.utility.localeCompare("é", "e\u{0301}", null, null));
    try std.testing.expectEqual(@as(isize, 0), z.utility.localeCompare("Å", "A\u{030a}", null, null));
    try std.testing.expectEqual(@as(isize, 0), z.utility.localeCompare("가", "가", null, null));
    try std.testing.expectEqual(@as(isize, 0), z.utility.localeCompare("s\u{0307}\u{0323}", "ṩ", null, null));
    var str = try z.ZString.fromCharCodeEcma(A, &.{ 0xd800, 0xd83d, 0xde00 });
    defer str.deinit();
    var iterator = str.iterator();
    try std.testing.expectEqual(@as(?u21, 0xd800), iterator.next());
    try std.testing.expectEqual(@as(?u21, 0x1f600), iterator.next());
    try std.testing.expectEqual(@as(?u21, null), iterator.next());
    try expectOwned("a\\nb!", try z.ZString.raw(A, &.{ "a\\n", "!" }, &.{"b"}));
}

fn allocationScenario(allocator: std.mem.Allocator) !void {
    const split = try z.split.split(allocator, "😀😀", "\xed\xa0\xbd", null);
    defer z.split.freeSplitResult(allocator, split);
    const norm = try z.utility.normalizeStrict(allocator, "éﬁ가", "NFKD");
    defer allocator.free(norm);
    const upper = try z.case.toUpperCase(allocator, "ßé𐐨");
    defer allocator.free(upper);
    const padded = try z.padding.padStart(allocator, "x", 20, "😀");
    defer allocator.free(padded);
    var factory = try z.ZString.fromCharCodeEcma(allocator, &.{ 0xd800, 65, 0xd83d, 0xde00 });
    defer factory.deinit();
}

test "regression - allocating operations release all partial results" {
    try std.testing.checkAllAllocationFailures(A, allocationScenario, .{});
}

test "regression - strict regex flags, named captures and empty matches" {
    var re = try z.CompiledRegex.compile(A, "(?<letter>a)(b)?", "gdi");
    defer re.deinit();
    const matches = try re.matchAll("A ab");
    defer z.compiled_regex.freeMatches(A, matches);
    try std.testing.expectEqual(@as(usize, 2), matches.len);
    try std.testing.expectEqual(@as(usize, 2), matches[0].captures.len);
    try std.testing.expect(matches[0].captures[1] == null);
    try std.testing.expectEqualStrings("A", matches[0].named("letter").?);
    try std.testing.expectEqual(@as(usize, 2), matches[1].index);
    try expectOwned("AA- aab-b", try re.replaceAll("A ab", "$<letter>$&-$2"));
    try std.testing.expectError(error.InvalidFlags, z.CompiledRegex.compile(A, "a", "gg"));
    try std.testing.expectError(error.IncompatibleFlags, z.CompiledRegex.compile(A, "a", "uv"));
    var empty = try z.CompiledRegex.compile(A, "", "g");
    defer empty.deinit();
    const all = try empty.matchAll("😀");
    defer z.compiled_regex.freeMatches(A, all);
    try std.testing.expectEqual(@as(usize, 3), all.len);
    try expectOwned("-\xed\xa0\xbd-\xed\xb8\x80-", try empty.replaceAll("😀", "-"));
    var unicode = try z.CompiledRegex.compile(A, "", "gu");
    defer unicode.deinit();
    const points = try unicode.matchAll("😀");
    defer z.compiled_regex.freeMatches(A, points);
    try std.testing.expectEqual(@as(usize, 2), points.len);
}

test "regression - regex split includes nullable captures and zero width semantics" {
    var re = try z.CompiledRegex.compile(A, "(\\d)|(x)", "");
    defer re.deinit();
    const pieces = try re.split("a1b", null);
    defer z.compiled_regex.freeSplit(A, pieces);
    try std.testing.expectEqual(@as(usize, 4), pieces.len);
    try std.testing.expectEqualStrings("a", pieces[0].?);
    try std.testing.expectEqualStrings("1", pieces[1].?);
    try std.testing.expect(pieces[2] == null);
    try std.testing.expectEqualStrings("b", pieces[3].?);
    var empty = try z.CompiledRegex.compile(A, "", "");
    defer empty.deinit();
    const units = try empty.split("😀", null);
    defer z.compiled_regex.freeSplit(A, units);
    try std.testing.expectEqual(@as(usize, 2), units.len);
    try std.testing.expectEqualStrings("\xed\xa0\xbd", units[0].?);
}

fn callback(_: ?*anyopaque, m: z.DetailedMatch, allocator: std.mem.Allocator) ![]u8 {
    return z.case.toUpperCase(allocator, m.match);
}

test "regression - literal replacement and callbacks" {
    try expectOwned("3X14 [3.14]", try z.compiled_regex.replaceLiteral(A, "3X14 3.14", "3.14", "[$&]"));
    try expectOwned("-a-b-", try z.compiled_regex.replaceAllLiteral(A, "ab", "", "-"));
    var re = try z.CompiledRegex.compile(A, "[a-z]+", "g");
    defer re.deinit();
    try expectOwned("HELLO WORLD", try re.replaceWith("hello world", null, callback));
    const subject = try z.PreparedSubject.init(A, "one two");
    defer subject.deinit();
    try std.testing.expectEqual(@as(usize, 4), (try re.execAt(subject, 4)).?.index);
}

fn regexAllocations(allocator: std.mem.Allocator) !void {
    var re = try z.CompiledRegex.compile(allocator, "(?<name>a)(b)?", "g");
    defer re.deinit();
    const matches = try re.matchAll("a ab");
    defer z.compiled_regex.freeMatches(allocator, matches);
    const replaced = try re.replaceAll("a ab", "$<name>-$2");
    defer allocator.free(replaced);
    const pieces = try re.split("a ab", null);
    defer z.compiled_regex.freeSplit(allocator, pieces);
}

test "regression - regex partial allocations are freed" {
    try std.testing.checkAllAllocationFailures(A, regexAllocations, .{});
}

test "regression - prepared execution performs no allocations after warmup" {
    var counting = std.testing.FailingAllocator.init(A, .{});
    var re = try z.CompiledRegex.compile(counting.allocator(), "[a-z]+", "g");
    defer re.deinit();
    const subject = try z.PreparedSubject.init(counting.allocator(), "one two three");
    defer subject.deinit();
    _ = try re.execAt(subject, 0);
    const before = counting.allocations;
    for (0..1000) |_| try std.testing.expectEqual(@as(usize, 4), (try re.execAt(subject, 4)).?.index);
    try std.testing.expectEqual(before, counting.allocations);
}

test "regression - sanitizer and legacy regex split handle surrogate boundaries" {
    try expectOwned("😀", try z.utf16.sanitizeWtf8ToUtf8(A, "\xed\xa0\xbd\xed\xb8\x80"));
    const pieces = try z.regex.splitRegex(A, "a1b", "(\\d)|(x)", null);
    defer z.split.freeSplitResult(A, pieces);
    try std.testing.expectEqual(@as(usize, 4), pieces.len);
    try std.testing.expectEqualStrings("1", pieces[1]);
    try std.testing.expectEqualStrings("", pieces[2]);
    const halves = try z.regex.splitRegex(A, "😀", "", null);
    defer z.split.freeSplitResult(A, halves);
    try std.testing.expectEqual(@as(usize, 2), halves.len);
    try std.testing.expectEqualStrings("\xed\xa0\xbd", halves[0]);
    try std.testing.expectError(error.OutOfMemory, z.padding.padStart(A, "", std.math.maxInt(isize), "😀"));
}

test "regression - strict regex validates bytes, preserves surrogate patterns and limits" {
    try std.testing.expectError(error.InvalidUtf8, z.CompiledRegex.compile(A, "\xff", ""));
    try std.testing.expectError(error.InvalidUtf8, z.PreparedSubject.init(A, "\xff"));
    var re = try z.CompiledRegex.compile(A, "\xed\xa0\xbd", "");
    defer re.deinit();
    const found = (try re.match("😀", 0)).?;
    defer found.deinit();
    try std.testing.expectEqual(@as(usize, 1), found.end);
    try std.testing.expectEqualStrings("\xed\xa0\xbd", found.match);
    var budget = try z.CompiledRegex.compile(A, "(a+)\\1", "");
    defer budget.deinit();
    budget.setLimits(.{ .max_steps = 1 });
    const subject = try z.PreparedSubject.init(A, "aaaa");
    defer subject.deinit();
    try std.testing.expectError(error.StepLimitExceeded, budget.execAt(subject, 0));
}
