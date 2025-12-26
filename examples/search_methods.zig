const std = @import("std");
const zstring = @import("zstring");

pub fn main() !void {
    std.debug.print("=== z-string Search Methods Examples ===\n\n", .{});

    // Example 1: indexOf()
    std.debug.print("1. indexOf() - Find first occurrence\n", .{});
    {
        const str = zstring.ZString.init("hello world hello");

        const idx1 = str.indexOf("hello", null);
        std.debug.print("   indexOf('hello') = {}\n", .{idx1}); // 0

        const idx2 = str.indexOf("world", null);
        std.debug.print("   indexOf('world') = {}\n", .{idx2}); // 6

        const idx3 = str.indexOf("o", null);
        std.debug.print("   indexOf('o') = {}\n", .{idx3}); // 4

        const idx4 = str.indexOf("o", 5);
        std.debug.print("   indexOf('o', 5) = {}\n", .{idx4}); // 7

        const idx5 = str.indexOf("xyz", null);
        std.debug.print("   indexOf('xyz') = {} (not found)\n", .{idx5}); // -1
    }

    // Example 2: lastIndexOf()
    std.debug.print("\n2. lastIndexOf() - Find last occurrence\n", .{});
    {
        const str = zstring.ZString.init("hello world hello");

        const idx1 = str.lastIndexOf("hello", null);
        std.debug.print("   lastIndexOf('hello') = {}\n", .{idx1}); // 12

        const idx2 = str.lastIndexOf("o", null);
        std.debug.print("   lastIndexOf('o') = {}\n", .{idx2}); // 16

        const idx3 = str.lastIndexOf("hello", 10);
        std.debug.print("   lastIndexOf('hello', 10) = {} (finds first)\n", .{idx3}); // 0
    }

    // Example 3: includes()
    std.debug.print("\n3. includes() - Check if string contains substring\n", .{});
    {
        const str = zstring.ZString.init("hello world");

        std.debug.print("   includes('world') = {}\n", .{str.includes("world", null)}); // true
        std.debug.print("   includes('hello') = {}\n", .{str.includes("hello", null)}); // true
        std.debug.print("   includes('xyz') = {}\n", .{str.includes("xyz", null)}); // false
        std.debug.print("   includes('world', 7) = {} (after 'world')\n", .{str.includes("world", 7)}); // false
    }

    // Example 4: startsWith()
    std.debug.print("\n4. startsWith() - Check if string starts with substring\n", .{});
    {
        const str = zstring.ZString.init("hello world");

        std.debug.print("   startsWith('hello') = {}\n", .{str.startsWith("hello", null)}); // true
        std.debug.print("   startsWith('world') = {}\n", .{str.startsWith("world", null)}); // false
        std.debug.print("   startsWith('world', 6) = {}\n", .{str.startsWith("world", 6)}); // true
        std.debug.print("   startsWith('h') = {}\n", .{str.startsWith("h", null)}); // true
    }

    // Example 5: endsWith()
    std.debug.print("\n5. endsWith() - Check if string ends with substring\n", .{});
    {
        const str = zstring.ZString.init("hello world");

        std.debug.print("   endsWith('world') = {}\n", .{str.endsWith("world", null)}); // true
        std.debug.print("   endsWith('hello') = {}\n", .{str.endsWith("hello", null)}); // false
        std.debug.print("   endsWith('hello', 5) = {} (as if string was 'hello')\n", .{str.endsWith("hello", 5)}); // true
        std.debug.print("   endsWith('d') = {}\n", .{str.endsWith("d", null)}); // true
    }

    // Example 6: Emoji handling (UTF-16 indices)
    std.debug.print("\n6. Emoji handling (UTF-16 indices)\n", .{});
    {
        const str = zstring.ZString.init("hello😀world");

        std.debug.print("   String: 'hello😀world'\n", .{});
        std.debug.print("   Length (UTF-16): {}\n", .{str.lengthConst()});

        // 😀 is at UTF-16 index 5 (after "hello" which is 5 chars)
        // and takes 2 UTF-16 code units
        const idx = str.indexOf("😀", null);
        std.debug.print("   indexOf('😀') = {}\n", .{idx}); // 5

        const has_emoji = str.includes("😀", null);
        std.debug.print("   includes('😀') = {}\n", .{has_emoji}); // true

        // "world" starts at UTF-16 index 7 (5 + 2 for emoji)
        const starts_world = str.startsWith("world", 7);
        std.debug.print("   startsWith('world', 7) = {}\n", .{starts_world}); // true
    }

    // Example 7: Case sensitivity
    std.debug.print("\n7. Case sensitivity\n", .{});
    {
        const str = zstring.ZString.init("Hello World");

        std.debug.print("   includes('hello') = {} (case sensitive!)\n", .{str.includes("hello", null)}); // false
        std.debug.print("   includes('Hello') = {}\n", .{str.includes("Hello", null)}); // true
        std.debug.print("   startsWith('hello') = {}\n", .{str.startsWith("hello", null)}); // false
        std.debug.print("   startsWith('Hello') = {}\n", .{str.startsWith("Hello", null)}); // true
    }

    // Example 8: Empty string behavior
    std.debug.print("\n8. Empty string behavior\n", .{});
    {
        const str = zstring.ZString.init("hello");

        std.debug.print("   indexOf('') = {}\n", .{str.indexOf("", null)}); // 0
        std.debug.print("   indexOf('', 3) = {}\n", .{str.indexOf("", 3)}); // 3
        std.debug.print("   includes('') = {}\n", .{str.includes("", null)}); // true
        std.debug.print("   startsWith('') = {}\n", .{str.startsWith("", null)}); // true
        std.debug.print("   endsWith('') = {}\n", .{str.endsWith("", null)}); // true
    }

    // Example 9: Practical use cases
    std.debug.print("\n9. Practical use cases\n", .{});
    {
        const url = zstring.ZString.init("https://example.com/path/to/file.html");

        std.debug.print("   URL: '{s}'\n", .{url.data});

        // Check protocol
        if (url.startsWith("https://", null)) {
            std.debug.print("   ✓ Secure connection\n", .{});
        }

        // Check file extension
        if (url.endsWith(".html", null)) {
            std.debug.print("   ✓ HTML file\n", .{});
        }

        // Find domain start
        const domain_start = url.indexOf("://", null) + 3;
        std.debug.print("   Domain starts at index: {}\n", .{domain_start});
    }

    std.debug.print("\n=== Done ===\n", .{});
}
