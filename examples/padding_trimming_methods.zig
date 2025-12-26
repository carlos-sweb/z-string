const std = @import("std");
const zstring = @import("zstring");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== z-string Padding & Trimming Methods Examples ===\n\n", .{});

    // Example 1: padStart() - Pad at the beginning
    std.debug.print("1. padStart() - Add padding to the start of a string\n", .{});
    {
        const str = zstring.ZString.init("5");

        const padded1 = try str.padStart(allocator, 3, "0");
        defer allocator.free(padded1);
        std.debug.print("   '5'.padStart(3, '0') = '{s}'\n", .{padded1}); // "005"

        const padded2 = try str.padStart(allocator, 5, null);
        defer allocator.free(padded2);
        std.debug.print("   '5'.padStart(5) = '{s}' (default space)\n", .{padded2}); // "    5"

        const multi = zstring.ZString.init("abc");
        const padded3 = try multi.padStart(allocator, 10, "foo");
        defer allocator.free(padded3);
        std.debug.print("   'abc'.padStart(10, 'foo') = '{s}'\n", .{padded3}); // "foofoofabc"
    }

    // Example 2: padEnd() - Pad at the end
    std.debug.print("\n2. padEnd() - Add padding to the end of a string\n", .{});
    {
        const str = zstring.ZString.init("5");

        const padded1 = try str.padEnd(allocator, 3, "0");
        defer allocator.free(padded1);
        std.debug.print("   '5'.padEnd(3, '0') = '{s}'\n", .{padded1}); // "500"

        const multi = zstring.ZString.init("abc");
        const padded2 = try multi.padEnd(allocator, 10, ".");
        defer allocator.free(padded2);
        std.debug.print("   'abc'.padEnd(10, '.') = '{s}'\n", .{padded2}); // "abc......."
    }

    // Example 3: Practical padding use cases
    std.debug.print("\n3. Practical padding use cases\n", .{});
    {
        // Creating formatted numbers
        const num = zstring.ZString.init("42");
        const formatted = try num.padStart(allocator, 5, "0");
        defer allocator.free(formatted);
        std.debug.print("   Order number: {s}\n", .{formatted}); // "00042"

        // Creating table columns
        const header = zstring.ZString.init("Name");
        const column = try header.padEnd(allocator, 20, " ");
        defer allocator.free(column);
        std.debug.print("   Table header: |{s}|\n", .{column}); // "Name                |"

        // Time formatting
        const hour = zstring.ZString.init("9");
        const minute = zstring.ZString.init("5");
        const hour_pad = try hour.padStart(allocator, 2, "0");
        defer allocator.free(hour_pad);
        const minute_pad = try minute.padStart(allocator, 2, "0");
        defer allocator.free(minute_pad);
        std.debug.print("   Time: {s}:{s}\n", .{ hour_pad, minute_pad }); // "09:05"
    }

    // Example 4: trim() - Remove whitespace from both ends
    std.debug.print("\n4. trim() - Remove whitespace from both ends\n", .{});
    {
        const str1 = zstring.ZString.init("  hello  ");
        const trimmed1 = try str1.trim(allocator);
        defer allocator.free(trimmed1);
        std.debug.print("   '  hello  '.trim() = '{s}'\n", .{trimmed1}); // "hello"

        const str2 = zstring.ZString.init("\t\n  hello world  \r\n");
        const trimmed2 = try str2.trim(allocator);
        defer allocator.free(trimmed2);
        std.debug.print("   '\\t\\n  hello world  \\r\\n'.trim() = '{s}'\n", .{trimmed2}); // "hello world"

        const str3 = zstring.ZString.init("   ");
        const trimmed3 = try str3.trim(allocator);
        defer allocator.free(trimmed3);
        std.debug.print("   '   '.trim() = '{s}' (empty)\n", .{trimmed3}); // ""
    }

    // Example 5: trimStart() / trimLeft() - Remove leading whitespace
    std.debug.print("\n5. trimStart() - Remove whitespace from the start\n", .{});
    {
        const str = zstring.ZString.init("  hello  ");

        const trimmed = try str.trimStart(allocator);
        defer allocator.free(trimmed);
        std.debug.print("   '  hello  '.trimStart() = '{s}'\n", .{trimmed}); // "hello  "

        // trimLeft is an alias
        const trimmed_left = try str.trimLeft(allocator);
        defer allocator.free(trimmed_left);
        std.debug.print("   '  hello  '.trimLeft() = '{s}' (same as trimStart)\n", .{trimmed_left}); // "hello  "
    }

    // Example 6: trimEnd() / trimRight() - Remove trailing whitespace
    std.debug.print("\n6. trimEnd() - Remove whitespace from the end\n", .{});
    {
        const str = zstring.ZString.init("  hello  ");

        const trimmed = try str.trimEnd(allocator);
        defer allocator.free(trimmed);
        std.debug.print("   '  hello  '.trimEnd() = '{s}'\n", .{trimmed}); // "  hello"

        // trimRight is an alias
        const trimmed_right = try str.trimRight(allocator);
        defer allocator.free(trimmed_right);
        std.debug.print("   '  hello  '.trimRight() = '{s}' (same as trimEnd)\n", .{trimmed_right}); // "  hello"
    }

    // Example 7: ECMAScript whitespace characters
    std.debug.print("\n7. ECMAScript whitespace characters (all trimmed)\n", .{});
    {
        // Various whitespace types
        const tab = zstring.ZString.init("\thello\t");
        const tab_result = try tab.trim(allocator);
        defer allocator.free(tab_result);
        std.debug.print("   TAB: '\\thello\\t' -> '{s}'\n", .{tab_result});

        const newline = zstring.ZString.init("\nhello\n");
        const newline_result = try newline.trim(allocator);
        defer allocator.free(newline_result);
        std.debug.print("   LF: '\\nhello\\n' -> '{s}'\n", .{newline_result});

        const nbsp = zstring.ZString.init("\u{00A0}hello\u{00A0}");
        const nbsp_result = try nbsp.trim(allocator);
        defer allocator.free(nbsp_result);
        std.debug.print("   NBSP: 'U+00A0 hello U+00A0' -> '{s}'\n", .{nbsp_result});
    }

    // Example 8: Practical trimming use cases
    std.debug.print("\n8. Practical trimming use cases\n", .{});
    {
        // Cleaning user input
        const user_input = zstring.ZString.init("  john.doe@example.com  \n");
        const cleaned = try user_input.trim(allocator);
        defer allocator.free(cleaned);
        std.debug.print("   User input cleaned: '{s}'\n", .{cleaned}); // "john.doe@example.com"

        // Processing text from files
        const file_line = zstring.ZString.init("   data: value   \r\n");
        const processed = try file_line.trim(allocator);
        defer allocator.free(processed);
        std.debug.print("   File line processed: '{s}'\n", .{processed}); // "data: value"
    }

    // Example 9: Emoji with padding and trimming
    std.debug.print("\n9. Emoji handling (UTF-16 indices)\n", .{});
    {
        const emoji = zstring.ZString.init("😀");
        std.debug.print("   Emoji: '😀'\n", .{});
        std.debug.print("   Length (UTF-16): {}\n", .{emoji.lengthConst()}); // 2

        // Padding with emoji (2 UTF-16 code units)
        const padded = try emoji.padStart(allocator, 5, "x");
        defer allocator.free(padded);
        std.debug.print("   '😀'.padStart(5, 'x') = '{s}'\n", .{padded}); // "xxx😀"

        // Trimming preserves emoji
        const emoji_padded = zstring.ZString.init("  😀  ");
        const trimmed = try emoji_padded.trim(allocator);
        defer allocator.free(trimmed);
        std.debug.print("   '  😀  '.trim() = '{s}'\n", .{trimmed}); // "😀"
    }

    // Example 10: Combining padding and trimming
    std.debug.print("\n10. Combining operations\n", .{});
    {
        // Trim then pad
        const original = zstring.ZString.init("  value  ");
        const trimmed = try original.trim(allocator);
        defer allocator.free(trimmed);
        std.debug.print("   Original: '{s}'\n", .{original.data});
        std.debug.print("   After trim: '{s}'\n", .{trimmed});

        const trimmed_str = zstring.ZString.init(trimmed);
        const padded = try trimmed_str.padEnd(allocator, 10, "-");
        defer allocator.free(padded);
        std.debug.print("   After padEnd(10, '-'): '{s}'\n", .{padded}); // "value-----"
    }

    // Example 11: Building formatted output
    std.debug.print("\n11. Building formatted output\n", .{});
    {
        // Creating a simple table
        const separator = zstring.ZString.init("-");
        const sep_line = try separator.repeat(allocator, 40);
        defer allocator.free(sep_line);

        std.debug.print("   {s}\n", .{sep_line});

        const name = zstring.ZString.init("Product");
        const price = zstring.ZString.init("$99");

        const name_col = try name.padEnd(allocator, 20, " ");
        defer allocator.free(name_col);

        const price_col = try price.padStart(allocator, 10, " ");
        defer allocator.free(price_col);

        std.debug.print("   {s}|{s}\n", .{ name_col, price_col });
        std.debug.print("   {s}\n", .{sep_line});
    }

    std.debug.print("\n=== Done ===\n", .{});
}
