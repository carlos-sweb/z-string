const std = @import("std");
const zstring = @import("zstring");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== z-string Transform Methods Examples ===\n\n", .{});

    // Example 1: slice()
    std.debug.print("1. slice() - Extract substring (supports negative indices)\n", .{});
    {
        const str = zstring.ZString.init("hello world");

        const part1 = try str.slice(allocator, 0, 5);
        defer allocator.free(part1);
        std.debug.print("   slice(0, 5) = '{s}'\n", .{part1}); // "hello"

        const part2 = try str.slice(allocator, 6, 11);
        defer allocator.free(part2);
        std.debug.print("   slice(6, 11) = '{s}'\n", .{part2}); // "world"

        const part3 = try str.slice(allocator, -5, null);
        defer allocator.free(part3);
        std.debug.print("   slice(-5) = '{s}' (last 5 chars)\n", .{part3}); // "world"

        const part4 = try str.slice(allocator, -5, -1);
        defer allocator.free(part4);
        std.debug.print("   slice(-5, -1) = '{s}'\n", .{part4}); // "worl"
    }

    // Example 2: substring()
    std.debug.print("\n2. substring() - Extract substring (swaps if start > end)\n", .{});
    {
        const str = zstring.ZString.init("hello world");

        const part1 = try str.substring(allocator, 0, 5);
        defer allocator.free(part1);
        std.debug.print("   substring(0, 5) = '{s}'\n", .{part1}); // "hello"

        const part2 = try str.substring(allocator, 3, 1);
        defer allocator.free(part2);
        std.debug.print("   substring(3, 1) = '{s}' (swapped to 1, 3)\n", .{part2}); // "el"

        const part3 = try str.substring(allocator, -2, 5);
        defer allocator.free(part3);
        std.debug.print("   substring(-2, 5) = '{s}' (negative = 0)\n", .{part3}); // "hello"
    }

    // Example 3: slice vs substring
    std.debug.print("\n3. slice vs substring - Key differences\n", .{});
    {
        const str = zstring.ZString.init("hello");

        // Negative indices
        const slice_neg = try str.slice(allocator, -2, null);
        defer allocator.free(slice_neg);

        const substring_neg = try str.substring(allocator, -2, null);
        defer allocator.free(substring_neg);

        std.debug.print("   slice(-2) = '{s}'\n", .{slice_neg}); // "lo"
        std.debug.print("   substring(-2) = '{s}'\n", .{substring_neg}); // "hello"

        // Start > end
        const slice_swap = try str.slice(allocator, 3, 1);
        defer allocator.free(slice_swap);

        const substring_swap = try str.substring(allocator, 3, 1);
        defer allocator.free(substring_swap);

        std.debug.print("   slice(3, 1) = '{s}' (empty)\n", .{slice_swap}); // ""
        std.debug.print("   substring(3, 1) = '{s}' (swapped)\n", .{substring_swap}); // "el"
    }

    // Example 4: concat()
    std.debug.print("\n4. concat() - Combine strings\n", .{});
    {
        const str = zstring.ZString.init("hello");

        const result1 = try str.concat(allocator, &[_][]const u8{" world"});
        defer allocator.free(result1);
        std.debug.print("   concat(' world') = '{s}'\n", .{result1}); // "hello world"

        const result2 = try str.concat(allocator, &[_][]const u8{ " ", "beautiful", " ", "world" });
        defer allocator.free(result2);
        std.debug.print("   concat(' ', 'beautiful', ' ', 'world') = '{s}'\n", .{result2});
    }

    // Example 5: repeat()
    std.debug.print("\n5. repeat() - Repeat string N times\n", .{});
    {
        const str = zstring.ZString.init("abc");

        const result1 = try str.repeat(allocator, 0);
        defer allocator.free(result1);
        std.debug.print("   repeat(0) = '{s}' (empty)\n", .{result1}); // ""

        const result2 = try str.repeat(allocator, 1);
        defer allocator.free(result2);
        std.debug.print("   repeat(1) = '{s}'\n", .{result2}); // "abc"

        const result3 = try str.repeat(allocator, 3);
        defer allocator.free(result3);
        std.debug.print("   repeat(3) = '{s}'\n", .{result3}); // "abcabcabc"
    }

    // Example 6: Emoji with transformations
    std.debug.print("\n6. Emoji handling (UTF-16 indices)\n", .{});
    {
        const str = zstring.ZString.init("😀😃😄");

        std.debug.print("   String: '😀😃😄'\n", .{});
        std.debug.print("   Length (UTF-16): {}\n", .{str.lengthConst()}); // 6

        // Each emoji is 2 UTF-16 code units
        const first = try str.slice(allocator, 0, 2);
        defer allocator.free(first);
        std.debug.print("   slice(0, 2) = '{s}' (first emoji)\n", .{first}); // "😀"

        const second = try str.slice(allocator, 2, 4);
        defer allocator.free(second);
        std.debug.print("   slice(2, 4) = '{s}' (second emoji)\n", .{second}); // "😃"

        const first_zstr = zstring.ZString.init(first);
        const repeated = try first_zstr.repeat(allocator, 3);
        defer allocator.free(repeated);
        std.debug.print("   First emoji repeated 3x = '{s}'\n", .{repeated}); // "😀😀😀"
    }

    // Example 7: Practical use cases
    std.debug.print("\n7. Practical use cases\n", .{});
    {
        // Building a formatted string
        const name = zstring.ZString.init("John");
        const greeting = try name.concat(allocator, &[_][]const u8{ ", ", "welcome to z-string!" });
        defer allocator.free(greeting);
        std.debug.print("   Greeting: '{s}'\n", .{greeting});

        // Creating a separator line
        const dash = zstring.ZString.init("-");
        const separator = try dash.repeat(allocator, 40);
        defer allocator.free(separator);
        std.debug.print("   Separator: {s}\n", .{separator});

        // Extracting file extension
        const filename = zstring.ZString.init("document.txt");
        const last_dot = filename.indexOf(".", null);
        if (last_dot != -1) {
            const ext = try filename.slice(allocator, last_dot + 1, null);
            defer allocator.free(ext);
            std.debug.print("   File extension: '{s}'\n", .{ext}); // "txt"
        }
    }

    // Example 8: Chaining operations
    std.debug.print("\n8. Chaining operations\n", .{});
    {
        const original = zstring.ZString.init("  hello world  ");

        // Extract middle part
        const trimmed = try original.slice(allocator, 2, 13);
        defer allocator.free(trimmed);
        std.debug.print("   Original: '{s}'\n", .{original.data});
        std.debug.print("   After slice(2, 13): '{s}'\n", .{trimmed});

        // Get just first word
        const trimmed_str = zstring.ZString.init(trimmed);
        const first_word = try trimmed_str.slice(allocator, 0, 5);
        defer allocator.free(first_word);
        std.debug.print("   First word: '{s}'\n", .{first_word});

        // Repeat it
        const repeated = try zstring.ZString.init(first_word).repeat(allocator, 2);
        defer allocator.free(repeated);
        std.debug.print("   Repeated: '{s}'\n", .{repeated});
    }

    std.debug.print("\n=== Done ===\n", .{});
}
