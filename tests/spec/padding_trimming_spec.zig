const std = @import("std");
const zstring = @import("zstring");

// ============================================================================
// Padding Spec Tests
// ============================================================================

test "spec - padStart: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.padstart
    //
    // JavaScript behavior:
    // "5".padStart(3, "0") -> "005"
    // "abc".padStart(10) -> "       abc"
    // "abc".padStart(6, "123456") -> "123abc"
    // "abc".padStart(2, "0") -> "abc"

    const allocator = std.testing.allocator;

    const str1 = zstring.ZString.init("5");
    const result1 = try str1.padStart(allocator, 3, "0");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("005", result1);

    const str2 = zstring.ZString.init("abc");
    const result2 = try str2.padStart(allocator, 10, null);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("       abc", result2);

    const str3 = zstring.ZString.init("abc");
    const result3 = try str3.padStart(allocator, 6, "123456");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("123abc", result3);

    const str4 = zstring.ZString.init("abc");
    const result4 = try str4.padStart(allocator, 2, "0");
    defer allocator.free(result4);
    try std.testing.expectEqualStrings("abc", result4);
}

test "spec - padStart: multi-character pad" {
    const allocator = std.testing.allocator;

    // "abc".padStart(10, "foo") -> "foofoofabc"
    const str = zstring.ZString.init("abc");
    const result = try str.padStart(allocator, 10, "foo");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("foofoofabc", result);
}

test "spec - padStart: partial pad" {
    const allocator = std.testing.allocator;

    // "abc".padStart(5, "12") -> "12abc"
    const str = zstring.ZString.init("abc");
    const result = try str.padStart(allocator, 5, "12");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("12abc", result);
}

test "spec - padStart: empty string" {
    const allocator = std.testing.allocator;

    // "".padStart(3, "x") -> "xxx"
    const str = zstring.ZString.init("");
    const result = try str.padStart(allocator, 3, "x");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("xxx", result);
}

test "spec - padStart: empty pad string" {
    const allocator = std.testing.allocator;

    // "abc".padStart(10, "") -> "abc"
    const str = zstring.ZString.init("abc");
    const result = try str.padStart(allocator, 10, "");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abc", result);
}

test "spec - padStart: negative target length" {
    const allocator = std.testing.allocator;

    // "abc".padStart(-1, "0") -> "abc"
    const str = zstring.ZString.init("abc");
    const result = try str.padStart(allocator, -1, "0");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abc", result);
}

test "spec - padStart: UTF-16 length calculation" {
    const allocator = std.testing.allocator;

    // Emoji (2 UTF-16 code units)
    // "😀".padStart(5, "x") -> "xxx😀"
    const str = zstring.ZString.init("😀");
    const result = try str.padStart(allocator, 5, "x");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("xxx😀", result);
}

test "spec - padEnd: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.padend
    //
    // JavaScript behavior:
    // "5".padEnd(3, "0") -> "500"
    // "abc".padEnd(10) -> "abc       "
    // "abc".padEnd(6, "123456") -> "abc123"
    // "abc".padEnd(2, "0") -> "abc"

    const allocator = std.testing.allocator;

    const str1 = zstring.ZString.init("5");
    const result1 = try str1.padEnd(allocator, 3, "0");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("500", result1);

    const str2 = zstring.ZString.init("abc");
    const result2 = try str2.padEnd(allocator, 10, null);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("abc       ", result2);

    const str3 = zstring.ZString.init("abc");
    const result3 = try str3.padEnd(allocator, 6, "123456");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("abc123", result3);

    const str4 = zstring.ZString.init("abc");
    const result4 = try str4.padEnd(allocator, 2, "0");
    defer allocator.free(result4);
    try std.testing.expectEqualStrings("abc", result4);
}

test "spec - padEnd: multi-character pad" {
    const allocator = std.testing.allocator;

    // "abc".padEnd(10, "foo") -> "abcfoofoof"
    const str = zstring.ZString.init("abc");
    const result = try str.padEnd(allocator, 10, "foo");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abcfoofoof", result);
}

test "spec - padEnd: partial pad" {
    const allocator = std.testing.allocator;

    // "abc".padEnd(5, "12") -> "abc12"
    const str = zstring.ZString.init("abc");
    const result = try str.padEnd(allocator, 5, "12");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("abc12", result);
}

test "spec - padEnd: empty string" {
    const allocator = std.testing.allocator;

    // "".padEnd(3, "x") -> "xxx"
    const str = zstring.ZString.init("");
    const result = try str.padEnd(allocator, 3, "x");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("xxx", result);
}

test "spec - padEnd: UTF-16 length calculation" {
    const allocator = std.testing.allocator;

    // Emoji (2 UTF-16 code units)
    // "😀".padEnd(5, "x") -> "😀xxx"
    const str = zstring.ZString.init("😀");
    const result = try str.padEnd(allocator, 5, "x");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("😀xxx", result);
}

// ============================================================================
// Trimming Spec Tests
// ============================================================================

test "spec - trim: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.trim
    //
    // JavaScript behavior:
    // "  hello  ".trim() -> "hello"
    // "\t\nhello\r\n".trim() -> "hello"
    // "hello".trim() -> "hello"

    const allocator = std.testing.allocator;

    const str1 = zstring.ZString.init("  hello  ");
    const result1 = try str1.trim(allocator);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello", result1);

    const str2 = zstring.ZString.init("\t\nhello\r\n");
    const result2 = try str2.trim(allocator);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello", result2);

    const str3 = zstring.ZString.init("hello");
    const result3 = try str3.trim(allocator);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("hello", result3);
}

test "spec - trim: all whitespace" {
    const allocator = std.testing.allocator;

    // "   ".trim() -> ""
    const str1 = zstring.ZString.init("   ");
    const result1 = try str1.trim(allocator);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("", result1);

    // "\t\n\r".trim() -> ""
    const str2 = zstring.ZString.init("\t\n\r");
    const result2 = try str2.trim(allocator);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("", result2);
}

test "spec - trim: empty string" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("");
    const result = try str.trim(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "spec - trim: preserves internal whitespace" {
    const allocator = std.testing.allocator;

    // "  hello world  ".trim() -> "hello world"
    const str = zstring.ZString.init("  hello world  ");
    const result = try str.trim(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "spec - trim: Unicode whitespace" {
    const allocator = std.testing.allocator;

    // With NBSP (U+00A0)
    const nbsp = "\u{00A0}hello\u{00A0}";
    const str = zstring.ZString.init(nbsp);
    const result = try str.trim(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "spec - trim: ECMAScript whitespace characters" {
    // Verify that all ECMAScript whitespace characters are trimmed
    const allocator = std.testing.allocator;

    // TAB (U+0009)
    const tab = zstring.ZString.init("\thello\t");
    const tab_result = try tab.trim(allocator);
    defer allocator.free(tab_result);
    try std.testing.expectEqualStrings("hello", tab_result);

    // LF (U+000A)
    const lf = zstring.ZString.init("\nhello\n");
    const lf_result = try lf.trim(allocator);
    defer allocator.free(lf_result);
    try std.testing.expectEqualStrings("hello", lf_result);

    // VT (U+000B)
    const vt = zstring.ZString.init("\x0Bhello\x0B");
    const vt_result = try vt.trim(allocator);
    defer allocator.free(vt_result);
    try std.testing.expectEqualStrings("hello", vt_result);

    // FF (U+000C)
    const ff = zstring.ZString.init("\x0Chello\x0C");
    const ff_result = try ff.trim(allocator);
    defer allocator.free(ff_result);
    try std.testing.expectEqualStrings("hello", ff_result);

    // CR (U+000D)
    const cr = zstring.ZString.init("\rhello\r");
    const cr_result = try cr.trim(allocator);
    defer allocator.free(cr_result);
    try std.testing.expectEqualStrings("hello", cr_result);
}

test "spec - trimStart: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.trimstart
    //
    // JavaScript behavior:
    // "  hello  ".trimStart() -> "hello  "
    // "\t\nhello".trimStart() -> "hello"

    const allocator = std.testing.allocator;

    const str1 = zstring.ZString.init("  hello  ");
    const result1 = try str1.trimStart(allocator);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello  ", result1);

    const str2 = zstring.ZString.init("\t\nhello");
    const result2 = try str2.trimStart(allocator);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello", result2);

    const str3 = zstring.ZString.init("hello");
    const result3 = try str3.trimStart(allocator);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("hello", result3);
}

test "spec - trimStart: all whitespace" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("   ");
    const result = try str.trimStart(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "spec - trimEnd: basic functionality" {
    // https://tc39.es/ecma262/2025/#sec-string.prototype.trimend
    //
    // JavaScript behavior:
    // "  hello  ".trimEnd() -> "  hello"
    // "hello\t\n".trimEnd() -> "hello"

    const allocator = std.testing.allocator;

    const str1 = zstring.ZString.init("  hello  ");
    const result1 = try str1.trimEnd(allocator);
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("  hello", result1);

    const str2 = zstring.ZString.init("hello\t\n");
    const result2 = try str2.trimEnd(allocator);
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("hello", result2);

    const str3 = zstring.ZString.init("hello");
    const result3 = try str3.trimEnd(allocator);
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("hello", result3);
}

test "spec - trimEnd: all whitespace" {
    const allocator = std.testing.allocator;

    const str = zstring.ZString.init("   ");
    const result = try str.trimEnd(allocator);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("", result);
}

test "spec - trimStart vs trimEnd behavior" {
    const allocator = std.testing.allocator;
    const str_data = "  hello  ";
    const str = zstring.ZString.init(str_data);

    const start_result = try str.trimStart(allocator);
    defer allocator.free(start_result);
    try std.testing.expectEqualStrings("hello  ", start_result);

    const end_result = try str.trimEnd(allocator);
    defer allocator.free(end_result);
    try std.testing.expectEqualStrings("  hello", end_result);

    const both_result = try str.trim(allocator);
    defer allocator.free(both_result);
    try std.testing.expectEqualStrings("hello", both_result);
}

test "spec - trimLeft and trimRight aliases" {
    const allocator = std.testing.allocator;
    const str = zstring.ZString.init("  hello  ");

    // trimLeft is alias for trimStart
    const left_result = try str.trimLeft(allocator);
    defer allocator.free(left_result);
    try std.testing.expectEqualStrings("hello  ", left_result);

    // trimRight is alias for trimEnd
    const right_result = try str.trimRight(allocator);
    defer allocator.free(right_result);
    try std.testing.expectEqualStrings("  hello", right_result);
}

// ============================================================================
// Combined Padding + Trimming Tests
// ============================================================================

test "spec - combined: pad then trim" {
    const allocator = std.testing.allocator;

    // "5".padStart(5, " ") -> "    5"
    const str = zstring.ZString.init("5");
    const padded = try str.padStart(allocator, 5, " ");
    defer allocator.free(padded);
    try std.testing.expectEqualStrings("    5", padded);

    // "    5".trim() -> "5"
    const padded_str = zstring.ZString.init(padded);
    const trimmed = try padded_str.trim(allocator);
    defer allocator.free(trimmed);
    try std.testing.expectEqualStrings("5", trimmed);
}

test "spec - combined: trim then pad" {
    const allocator = std.testing.allocator;

    // "  abc  ".trim() -> "abc"
    const str = zstring.ZString.init("  abc  ");
    const trimmed = try str.trim(allocator);
    defer allocator.free(trimmed);
    try std.testing.expectEqualStrings("abc", trimmed);

    // "abc".padEnd(10, "-") -> "abc-------"
    const trimmed_str = zstring.ZString.init(trimmed);
    const padded = try trimmed_str.padEnd(allocator, 10, "-");
    defer allocator.free(padded);
    try std.testing.expectEqualStrings("abc-------", padded);
}
