const std = @import("std");
const zstring = @import("zstring");

/// Example: Safe string processing with comprehensive error handling
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== z-string Error Handling Examples ===\n\n", .{});

    // Example 1: Basic error handling with try
    try example1BasicErrorHandling(allocator);

    // Example 2: Handling optional returns
    try example2OptionalReturns(allocator);

    // Example 3: Error context and recovery
    try example3ErrorContext(allocator);

    // Example 4: Regex error handling
    try example4RegexErrors(allocator);

    // Example 5: Complex operations with errdefer
    try example5ComplexOperations(allocator);

    std.debug.print("\n=== All examples completed successfully ===\n", .{});
}

/// Example 1: Basic error handling with try
fn example1BasicErrorHandling(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 1: Basic Error Handling\n", .{});
    std.debug.print("--------------------------------\n", .{});

    const input = "  Hello, World!  ";
    const str = zstring.ZString.init(input);

    // Using try - propagates errors automatically
    const trimmed = try str.trim(allocator);
    defer allocator.free(trimmed);

    std.debug.print("Original: '{s}'\n", .{input});
    std.debug.print("Trimmed:  '{s}'\n", .{trimmed});

    // Chain operations with try
    const trimmed_str = zstring.ZString.init(trimmed);
    const upper = try trimmed_str.toUpperCase(allocator);
    defer allocator.free(upper);

    std.debug.print("Upper:    '{s}'\n", .{upper});
    std.debug.print("\n", .{});
}

/// Example 2: Handling optional returns
fn example2OptionalReturns(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 2: Optional Returns\n", .{});
    std.debug.print("---------------------------\n", .{});

    const str = zstring.ZString.init("Hello");

    // at() returns ?[]u8 (nullable)
    const char1 = try str.at(allocator, 0);
    if (char1) |c| {
        defer allocator.free(c);
        std.debug.print("Character at index 0: '{s}'\n", .{c});
    } else {
        std.debug.print("Index 0 is out of bounds\n", .{});
    }

    // Negative indexing
    const char2 = try str.at(allocator, -1);
    if (char2) |c| {
        defer allocator.free(c);
        std.debug.print("Character at index -1: '{s}'\n", .{c});
    } else {
        std.debug.print("Index -1 is out of bounds\n", .{});
    }

    // Out of bounds
    const char3 = try str.at(allocator, 100);
    if (char3) |c| {
        defer allocator.free(c);
        std.debug.print("Character at index 100: '{s}'\n", .{c});
    } else {
        std.debug.print("Index 100 is out of bounds (expected)\n", .{});
    }

    // charCodeAt returns ?u16
    const code = str.charCodeAt(0);
    if (code) |c| {
        std.debug.print("Code at index 0: {}\n", .{c});
    } else {
        std.debug.print("No code at index 0\n", .{});
    }

    std.debug.print("\n", .{});
}

/// Example 3: Error context and recovery
fn example3ErrorContext(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 3: Error Context and Recovery\n", .{});
    std.debug.print("-------------------------------------\n", .{});

    const inputs = [_][]const u8{
        "valid input",
        "",
        "another valid input",
    };

    for (inputs, 0..) |input, i| {
        processWithContext(allocator, input, i) catch |err| {
            std.debug.print("  [ERROR] Failed to process input {}: {}\n", .{ i, err });
            // Continue processing other inputs
            continue;
        };
    }

    std.debug.print("\n", .{});
}

fn processWithContext(allocator: std.mem.Allocator, input: []const u8, index: usize) !void {
    if (input.len == 0) {
        std.debug.print("  [SKIP] Input {} is empty\n", .{index});
        return error.EmptyInput;
    }

    const str = zstring.ZString.init(input);

    const upper = str.toUpperCase(allocator) catch |err| {
        std.debug.print("  [ERROR] Failed to uppercase input {}: {}\n", .{ index, err });
        return err;
    };
    defer allocator.free(upper);

    std.debug.print("  [OK] Input {}: '{s}' -> '{s}'\n", .{ index, input, upper });
}

/// Example 4: Regex error handling
fn example4RegexErrors(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 4: Regex Error Handling\n", .{});
    std.debug.print("-------------------------------\n", .{});

    const str = zstring.ZString.init("Hello 123 World 456");

    // search returns isize (-1 on error or not found)
    const index = try str.searchRegex(allocator, "[0-9]+");
    if (index >= 0) {
        std.debug.print("Found number at index: {}\n", .{index});
    } else {
        std.debug.print("No number found or error occurred\n", .{});
    }

    // match returns ?MatchArray
    const match_result = try str.matchRegex(allocator, "[0-9]+");
    if (match_result) |match| {
        defer match.deinit();
        std.debug.print("Matched: '{s}' at index {}\n", .{ match.match, match.index });
    } else {
        std.debug.print("No match found\n", .{});
    }

    // matchAll returns []MatchArray
    const all_matches = try str.matchAllRegex(allocator, "[0-9]+");
    defer zstring.ZString.freeMatchAllResult(allocator, all_matches);

    std.debug.print("Found {} matches:\n", .{all_matches.len});
    for (all_matches, 0..) |match, i| {
        std.debug.print("  Match {}: '{s}' at index {}\n", .{ i, match.match, match.index });
    }

    // Replace with error handling
    const replaced = str.replaceRegex(allocator, "[0-9]+", "XXX") catch |err| {
        std.debug.print("Replace failed: {}\n", .{err});
        return err;
    };
    defer allocator.free(replaced);

    std.debug.print("After replace: '{s}'\n", .{replaced});
    std.debug.print("\n", .{});
}

/// Example 5: Complex operations with errdefer
fn example5ComplexOperations(allocator: std.mem.Allocator) !void {
    std.debug.print("Example 5: Complex Operations with errdefer\n", .{});
    std.debug.print("-------------------------------------------\n", .{});

    const result = try complexStringTransform(allocator, "  Hello, World! 123  ");
    defer {
        allocator.free(result.trimmed);
        allocator.free(result.uppercase);
        allocator.free(result.replaced);
    }

    std.debug.print("Trimmed:   '{s}'\n", .{result.trimmed});
    std.debug.print("Uppercase: '{s}'\n", .{result.uppercase});
    std.debug.print("Replaced:  '{s}'\n", .{result.replaced});
    std.debug.print("\n", .{});
}

const TransformResult = struct {
    trimmed: []const u8,
    uppercase: []const u8,
    replaced: []const u8,
};

fn complexStringTransform(allocator: std.mem.Allocator, input: []const u8) !TransformResult {
    const str = zstring.ZString.init(input);

    // Step 1: Trim
    const trimmed = try str.trim(allocator);
    errdefer allocator.free(trimmed); // Only freed if subsequent operations fail

    // Step 2: Uppercase
    const trimmed_str = zstring.ZString.init(trimmed);
    const uppercase = try trimmed_str.toUpperCase(allocator);
    errdefer allocator.free(uppercase);

    // Step 3: Replace
    const replaced = try trimmed_str.replaceAllRegex(allocator, "[0-9]+", "NUM");
    errdefer allocator.free(replaced);

    // All operations succeeded, return all results
    // Caller is responsible for freeing
    return TransformResult{
        .trimmed = trimmed,
        .uppercase = uppercase,
        .replaced = replaced,
    };
}

// Additional helper example: Safe string builder
fn safeStringBuilder(allocator: std.mem.Allocator) ![]const u8 {
    var parts = std.ArrayList([]const u8).init(allocator);
    defer {
        for (parts.items) |part| {
            allocator.free(part);
        }
        parts.deinit();
    }

    const str1 = zstring.ZString.init("Hello");
    const upper1 = try str1.toUpperCase(allocator);
    try parts.append(upper1);

    const str2 = zstring.ZString.init("World");
    const upper2 = try str2.toUpperCase(allocator);
    try parts.append(upper2);

    // Combine all parts
    const combined = zstring.ZString.init("");
    return try combined.concat(allocator, parts.items);
}
