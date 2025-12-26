const std = @import("std");
const zstring = @import("zstring");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== z-string Character Access Examples ===\n\n", .{});

    // Example 1: charAt()
    std.debug.print("1. charAt() - Get character at index\n", .{});
    {
        const str = zstring.ZString.init("Hello, World!");

        const ch0 = try str.charAt(allocator, 0);
        defer allocator.free(ch0);
        std.debug.print("   charAt(0) = '{s}'\n", .{ch0});

        const ch7 = try str.charAt(allocator, 7);
        defer allocator.free(ch7);
        std.debug.print("   charAt(7) = '{s}'\n", .{ch7});

        // Out of bounds returns empty string
        const ch100 = try str.charAt(allocator, 100);
        defer allocator.free(ch100);
        std.debug.print("   charAt(100) = '{s}' (empty)\n", .{ch100});
    }

    // Example 2: at() with negative indices
    std.debug.print("\n2. at() - Supports negative indexing\n", .{});
    {
        const str = zstring.ZString.init("Hello");

        const ch0 = try str.at(allocator, 0);
        if (ch0) |c| {
            defer allocator.free(c);
            std.debug.print("   at(0) = '{s}'\n", .{c});
        }

        const ch_last = try str.at(allocator, -1);
        if (ch_last) |c| {
            defer allocator.free(c);
            std.debug.print("   at(-1) = '{s}' (last character)\n", .{c});
        }

        const ch_first = try str.at(allocator, -5);
        if (ch_first) |c| {
            defer allocator.free(c);
            std.debug.print("   at(-5) = '{s}' (first character)\n", .{c});
        }

        // Out of bounds returns null
        const ch_invalid = try str.at(allocator, 100);
        if (ch_invalid == null) {
            std.debug.print("   at(100) = null (out of bounds)\n", .{});
        }
    }

    // Example 3: charCodeAt() - UTF-16 code units
    std.debug.print("\n3. charCodeAt() - Get UTF-16 code unit\n", .{});
    {
        const str = zstring.ZString.init("ABC");

        if (str.charCodeAt(0)) |code| {
            std.debug.print("   'A' code = {} (0x{X})\n", .{ code, code });
        }

        if (str.charCodeAt(1)) |code| {
            std.debug.print("   'B' code = {} (0x{X})\n", .{ code, code });
        }

        if (str.charCodeAt(2)) |code| {
            std.debug.print("   'C' code = {} (0x{X})\n", .{ code, code });
        }
    }

    // Example 4: Emoji handling (surrogate pairs)
    std.debug.print("\n4. Emoji handling (surrogate pairs)\n", .{});
    {
        const str = zstring.ZString.init("😀");

        std.debug.print("   String: '😀'\n", .{});
        std.debug.print("   Length (UTF-16): {}\n", .{str.lengthConst()});

        // charCodeAt returns surrogate code units
        if (str.charCodeAt(0)) |high| {
            std.debug.print("   charCodeAt(0) = {} (0x{X}) - high surrogate\n", .{ high, high });
        }

        if (str.charCodeAt(1)) |low| {
            std.debug.print("   charCodeAt(1) = {} (0x{X}) - low surrogate\n", .{ low, low });
        }

        // codePointAt returns the full code point
        if (str.codePointAt(0)) |cp| {
            std.debug.print("   codePointAt(0) = {} (U+{X}) - full emoji\n", .{ cp, cp });
        }
    }

    // Example 5: codePointAt() - Full Unicode code points
    std.debug.print("\n5. codePointAt() - Full Unicode code points\n", .{});
    {
        const str = zstring.ZString.init("A😀B");

        std.debug.print("   String: 'A😀B'\n", .{});
        std.debug.print("   Length (UTF-16): {}\n", .{str.lengthConst()});

        if (str.codePointAt(0)) |cp| {
            std.debug.print("   codePointAt(0) = U+{X} ('A')\n", .{cp});
        }

        if (str.codePointAt(1)) |cp| {
            std.debug.print("   codePointAt(1) = U+{X} (emoji)\n", .{cp});
        }

        if (str.codePointAt(2)) |cp| {
            std.debug.print("   codePointAt(2) = U+{X} (emoji low surrogate pos)\n", .{cp});
        }

        if (str.codePointAt(3)) |cp| {
            std.debug.print("   codePointAt(3) = U+{X} ('B')\n", .{cp});
        }
    }

    // Example 6: Unicode characters
    std.debug.print("\n6. Unicode character access\n", .{});
    {
        const str = zstring.ZString.init("café");

        const ch3 = try str.charAt(allocator, 3);
        defer allocator.free(ch3);
        std.debug.print("   'café'.charAt(3) = '{s}'\n", .{ch3});

        if (str.charCodeAt(3)) |code| {
            std.debug.print("   'é' code = {} (U+{X})\n", .{ code, code });
        }
    }

    // Example 7: Comparison - charAt vs at behavior
    std.debug.print("\n7. charAt vs at - behavior difference\n", .{});
    {
        const str = zstring.ZString.init("test");

        std.debug.print("   Out of bounds:\n", .{});

        const ch_oob = try str.charAt(allocator, 100);
        defer allocator.free(ch_oob);
        std.debug.print("     charAt(100) = '{s}' (empty string)\n", .{ch_oob});

        const at_oob = try str.at(allocator, 100);
        if (at_oob == null) {
            std.debug.print("     at(100) = null\n", .{});
        }

        std.debug.print("   Negative index:\n", .{});

        const ch_neg = try str.charAt(allocator, -1);
        defer allocator.free(ch_neg);
        std.debug.print("     charAt(-1) = '{s}' (empty string)\n", .{ch_neg});

        const at_neg = try str.at(allocator, -1);
        if (at_neg) |c| {
            defer allocator.free(c);
            std.debug.print("     at(-1) = '{s}' (last char)\n", .{c});
        }
    }

    std.debug.print("\n=== Done ===\n", .{});
}
