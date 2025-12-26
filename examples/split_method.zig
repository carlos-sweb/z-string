const std = @import("std");
const zstring = @import("zstring");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== z-string split() Method Examples ===\n\n", .{});

    // Example 1: Basic splitting
    std.debug.print("1. Basic splitting with comma separator\n", .{});
    {
        const str = zstring.ZString.init("a,b,c");
        const result = try str.split(allocator, ",", null);
        defer zstring.ZString.freeSplitResult(allocator, result);

        std.debug.print("   'a,b,c'.split(',') = [", .{});
        for (result, 0..) |part, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("'{s}'", .{part});
        }
        std.debug.print("]\n", .{});
    }

    // Example 2: Empty separator - split into characters
    std.debug.print("\n2. Empty separator - split into individual characters\n", .{});
    {
        const str = zstring.ZString.init("hello");
        const result = try str.split(allocator, "", null);
        defer zstring.ZString.freeSplitResult(allocator, result);

        std.debug.print("   'hello'.split('') = [", .{});
        for (result, 0..) |char, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("'{s}'", .{char});
        }
        std.debug.print("]\n", .{});
    }

    // Example 3: Undefined separator - returns whole string
    std.debug.print("\n3. Undefined separator - returns array with whole string\n", .{});
    {
        const str = zstring.ZString.init("hello world");
        const result = try str.split(allocator, null, null);
        defer zstring.ZString.freeSplitResult(allocator, result);

        std.debug.print("   'hello world'.split(null) = ['{s}']\n", .{result[0]});
    }

    // Example 4: Using limit
    std.debug.print("\n4. Using limit parameter\n", .{});
    {
        const str = zstring.ZString.init("a,b,c,d,e");

        // Limit 3
        const result1 = try str.split(allocator, ",", 3);
        defer zstring.ZString.freeSplitResult(allocator, result1);

        std.debug.print("   'a,b,c,d,e'.split(',', 3) = [", .{});
        for (result1, 0..) |part, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("'{s}'", .{part});
        }
        std.debug.print("]\n", .{});

        // Limit 0 - returns empty array
        const result2 = try str.split(allocator, ",", 0);
        defer zstring.ZString.freeSplitResult(allocator, result2);
        std.debug.print("   'a,b,c,d,e'.split(',', 0) = [] (empty)\n", .{});
    }

    // Example 5: Separator not found
    std.debug.print("\n5. Separator not found - returns whole string\n", .{});
    {
        const str = zstring.ZString.init("hello");
        const result = try str.split(allocator, ",", null);
        defer zstring.ZString.freeSplitResult(allocator, result);

        std.debug.print("   'hello'.split(',') = ['{s}']\n", .{result[0]});
    }

    // Example 6: Empty string
    std.debug.print("\n6. Splitting empty string\n", .{});
    {
        const str = zstring.ZString.init("");

        // With separator
        const result1 = try str.split(allocator, ",", null);
        defer zstring.ZString.freeSplitResult(allocator, result1);
        std.debug.print("   ''.split(',') = [''] (array with empty string)\n", .{});

        // With empty separator
        const result2 = try str.split(allocator, "", null);
        defer zstring.ZString.freeSplitResult(allocator, result2);
        std.debug.print("   ''.split('') = [] (empty array)\n", .{});
    }

    // Example 7: Separator at start/end
    std.debug.print("\n7. Separator at start/end creates empty strings\n", .{});
    {
        const str1 = zstring.ZString.init(",a,b");
        const result1 = try str1.split(allocator, ",", null);
        defer zstring.ZString.freeSplitResult(allocator, result1);

        std.debug.print("   ',a,b'.split(',') = [", .{});
        for (result1, 0..) |part, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("'{s}'", .{part});
        }
        std.debug.print("]\n", .{});

        const str2 = zstring.ZString.init("a,b,");
        const result2 = try str2.split(allocator, ",", null);
        defer zstring.ZString.freeSplitResult(allocator, result2);

        std.debug.print("   'a,b,'.split(',') = [", .{});
        for (result2, 0..) |part, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("'{s}'", .{part});
        }
        std.debug.print("]\n", .{});
    }

    // Example 8: Consecutive separators
    std.debug.print("\n8. Consecutive separators create empty strings\n", .{});
    {
        const str = zstring.ZString.init("a,,b");
        const result = try str.split(allocator, ",", null);
        defer zstring.ZString.freeSplitResult(allocator, result);

        std.debug.print("   'a,,b'.split(',') = [", .{});
        for (result, 0..) |part, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("'{s}'", .{part});
        }
        std.debug.print("]\n", .{});
    }

    // Example 9: Multi-character separator
    std.debug.print("\n9. Multi-character separator\n", .{});
    {
        const str = zstring.ZString.init("hello<br>world<br>test");
        const result = try str.split(allocator, "<br>", null);
        defer zstring.ZString.freeSplitResult(allocator, result);

        std.debug.print("   'hello<br>world<br>test'.split('<br>') = [", .{});
        for (result, 0..) |part, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("'{s}'", .{part});
        }
        std.debug.print("]\n", .{});
    }

    // Example 10: Unicode and emoji
    std.debug.print("\n10. Unicode and emoji handling\n", .{});
    {
        // Unicode
        const str1 = zstring.ZString.init("café,thé");
        const result1 = try str1.split(allocator, ",", null);
        defer zstring.ZString.freeSplitResult(allocator, result1);

        std.debug.print("   'café,thé'.split(',') = ['{s}', '{s}']\n", .{ result1[0], result1[1] });

        // Emoji with empty separator
        const str2 = zstring.ZString.init("a😀b");
        const result2 = try str2.split(allocator, "", null);
        defer zstring.ZString.freeSplitResult(allocator, result2);

        std.debug.print("   'a😀b'.split('') = [", .{});
        for (result2, 0..) |part, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("'{s}'", .{part});
        }
        std.debug.print("]\n", .{});
    }

    // Example 11: Real-world use cases
    std.debug.print("\n11. Real-world use cases\n", .{});
    {
        // CSV parsing
        std.debug.print("   CSV data parsing:\n", .{});
        const csv = zstring.ZString.init("John,Doe,30,Engineer");
        const fields = try csv.split(allocator, ",", null);
        defer zstring.ZString.freeSplitResult(allocator, fields);

        std.debug.print("      Name: {s} {s}\n", .{ fields[0], fields[1] });
        std.debug.print("      Age: {s}\n", .{fields[2]});
        std.debug.print("      Role: {s}\n", .{fields[3]});

        // Path parsing
        std.debug.print("\n   Path parsing:\n", .{});
        const path = zstring.ZString.init("/usr/local/bin");
        const parts = try path.split(allocator, "/", null);
        defer zstring.ZString.freeSplitResult(allocator, parts);

        std.debug.print("      Path components: ", .{});
        for (parts, 0..) |part, i| {
            if (i > 0) std.debug.print(" / ", .{});
            if (part.len == 0) {
                std.debug.print("[root]", .{});
            } else {
                std.debug.print("{s}", .{part});
            }
        }
        std.debug.print("\n", .{});

        // Sentence into words
        std.debug.print("\n   Sentence into words:\n", .{});
        const sentence = zstring.ZString.init("Hello world this is a test");
        const words = try sentence.split(allocator, " ", null);
        defer zstring.ZString.freeSplitResult(allocator, words);

        std.debug.print("      Word count: {}\n", .{words.len});
        std.debug.print("      Words: ", .{});
        for (words, 0..) |word, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("{s}", .{word});
        }
        std.debug.print("\n", .{});
    }

    // Example 12: Edge cases
    std.debug.print("\n12. Edge cases\n", .{});
    {
        // Only separator
        const str1 = zstring.ZString.init(",");
        const result1 = try str1.split(allocator, ",", null);
        defer zstring.ZString.freeSplitResult(allocator, result1);
        std.debug.print("   ','.split(',') = ['', ''] ({} empty strings)\n", .{result1.len});

        // Multiple consecutive separators
        const str2 = zstring.ZString.init(",,,");
        const result2 = try str2.split(allocator, ",", null);
        defer zstring.ZString.freeSplitResult(allocator, result2);
        std.debug.print("   ',,,'.split(',') = {} empty strings\n", .{result2.len});
    }

    std.debug.print("\n=== Done ===\n", .{});
}
