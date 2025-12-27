# Error Handling Guide

## Overview

z-string follows Zig's error handling philosophy: errors are values, not exceptions. All fallible operations return error unions, making error handling explicit and compile-time checked.

## Error Types

### Memory Allocation Errors

Most z-string methods allocate memory and can return `Allocator.Error`:

```zig
pub const Allocator.Error = error{
    OutOfMemory,
};
```

### Regex Errors

Regex methods can return additional errors from the zregexp library:

```zig
pub const RegexError = error{
    // Parse errors
    InvalidPattern,
    UnexpectedCharacter,
    UnbalancedParenthesis,

    // Compilation errors
    TooManyCaptures,
    InvalidBackreference,

    // Execution errors
    RecursionLimitExceeded,
    StepLimitExceeded,

    // Memory errors
    OutOfMemory,
};
```

## Best Practices

### 1. Always Handle Errors

**❌ Bad:**
```zig
const result = str.toUpperCase(allocator); // Compile error: error is ignored
```

**✅ Good:**
```zig
const result = try str.toUpperCase(allocator);
// or
const result = str.toUpperCase(allocator) catch |err| {
    std.log.err("Failed to convert to uppercase: {}", .{err});
    return err;
};
```

### 2. Clean Up Resources with `defer`

Always use `defer` to ensure memory is freed even when errors occur:

**✅ Good:**
```zig
const upper = try str.toUpperCase(allocator);
defer allocator.free(upper); // Always freed, even if error occurs below

// Use upper...
const sliced = try str.slice(allocator, 0, 5);
defer allocator.free(sliced);
```

### 3. Handle Null Results

Some methods return optional values (`?T`) instead of errors:

```zig
// charCodeAt returns null for out-of-bounds
const code = str.charCodeAt(10); // Returns ?u16

if (code) |c| {
    std.debug.print("Code: {}\n", .{c});
} else {
    std.debug.print("Out of bounds\n", .{});
}
```

### 4. Propagate Errors Appropriately

Use `try` to propagate errors up the call stack:

```zig
pub fn processString(allocator: Allocator, input: []const u8) ![]const u8 {
    const str = zstring.ZString.init(input);

    // Propagate error to caller
    const upper = try str.toUpperCase(allocator);
    defer allocator.free(upper);

    const trimmed = try str.trim(allocator);
    defer allocator.free(trimmed);

    return upper;
}
```

### 5. Provide Error Context

Catch errors and add context when appropriate:

```zig
pub fn safeTransform(allocator: Allocator, input: []const u8) ![]const u8 {
    const str = zstring.ZString.init(input);

    const result = str.toUpperCase(allocator) catch |err| {
        std.log.err("Failed to transform '{s}': {}", .{input, err});
        return error.TransformFailed;
    };

    return result;
}
```

## Common Error Scenarios

### Scenario 1: Out of Memory

```zig
const str = zstring.ZString.init("a" ** 1000000);

const result = str.repeat(allocator, 1000000) catch |err| switch (err) {
    error.OutOfMemory => {
        std.log.err("Not enough memory to repeat string\n", .{});
        return error.OutOfMemory;
    },
};
defer allocator.free(result);
```

### Scenario 2: Invalid Regex Pattern

```zig
const str = zstring.ZString.init("hello world");

// Invalid regex pattern
const result = str.searchRegex(allocator, "[invalid(") catch |err| {
    // searchRegex returns -1 on error, not an error union
    // This is for ECMAScript compatibility
};

// Better: check the result
const index = try str.searchRegex(allocator, "world");
if (index >= 0) {
    std.debug.print("Found at index: {}\n", .{index});
} else {
    std.debug.print("Not found or error\n", .{});
}
```

### Scenario 3: Working with Optional Results

```zig
const str = zstring.ZString.init("hello");

// match returns ?MatchArray
const match_result = try str.matchRegex(allocator, "l+");

if (match_result) |match| {
    defer match.deinit();
    std.debug.print("Matched: {s}\n", .{match.match});
} else {
    std.debug.print("No match found\n", .{});
}
```

## Complete Example with Error Handling

```zig
const std = @import("std");
const zstring = @import("zstring");

pub fn processUserInput(allocator: std.mem.Allocator, input: []const u8) !void {
    // Validate input is not empty
    if (input.len == 0) {
        return error.EmptyInput;
    }

    // Create ZString
    const str = zstring.ZString.init(input);

    // Trim whitespace
    const trimmed = str.trim(allocator) catch |err| {
        std.log.err("Failed to trim input: {}", .{err});
        return err;
    };
    defer allocator.free(trimmed);

    // Convert to lowercase
    const lower = blk: {
        const trimmed_str = zstring.ZString.init(trimmed);
        break :blk trimmed_str.toLowerCase(allocator) catch |err| {
            std.log.err("Failed to convert to lowercase: {}", .{err});
            return err;
        };
    };
    defer allocator.free(lower);

    // Search for pattern
    const lower_str = zstring.ZString.init(lower);
    const index = lower_str.searchRegex(allocator, "[0-9]+") catch |err| {
        std.log.warn("Regex search failed: {}", .{err});
        return; // Continue even if regex fails
    };

    if (index >= 0) {
        std.debug.print("Found number at index: {}\n", .{index});
    }

    // Replace all spaces
    const replaced = lower_str.replaceAllRegex(allocator, " ", "_") catch |err| {
        std.log.err("Failed to replace spaces: {}", .{err});
        return err;
    };
    defer allocator.free(replaced);

    std.debug.print("Final result: {s}\n", .{replaced});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Process input with proper error handling
    processUserInput(allocator, "  Hello World 123  ") catch |err| {
        std.log.err("Failed to process input: {}", .{err});
        return err;
    };
}
```

## Error Handling Checklist

When using z-string, always:

- ✅ Use `try` or `catch` for all fallible operations
- ✅ Use `defer` to free allocated memory
- ✅ Check for `null` when using optional return types
- ✅ Provide meaningful error messages
- ✅ Clean up resources in reverse order of allocation
- ✅ Consider using `errdefer` for complex cleanup scenarios

## Advanced: Using `errdefer`

For complex operations with multiple allocations:

```zig
pub fn complexOperation(allocator: Allocator, input: []const u8) !ComplexResult {
    const str = zstring.ZString.init(input);

    const part1 = try str.slice(allocator, 0, 10);
    errdefer allocator.free(part1); // Only freed if error occurs

    const part2 = try str.slice(allocator, 10, 20);
    errdefer allocator.free(part2);

    const part3 = try str.slice(allocator, 20, 30);
    errdefer allocator.free(part3);

    // If any operation fails, errdefer clauses run in reverse order

    return ComplexResult{
        .part1 = part1,
        .part2 = part2,
        .part3 = part3,
    };
}
```

## Testing Error Conditions

```zig
test "handle out of memory gracefully" {
    var failing_allocator = std.testing.FailingAllocator.init(
        std.testing.allocator,
        0, // Fail immediately
    );
    const allocator = failing_allocator.allocator();

    const str = zstring.ZString.init("hello");

    // Should return OutOfMemory error
    const result = str.toUpperCase(allocator);
    try std.testing.expectError(error.OutOfMemory, result);
}
```

## Summary

- All errors are explicit and checked at compile time
- Use `try` to propagate errors, `catch` to handle them
- Always clean up with `defer` or `errdefer`
- Check for `null` with optional types
- Provide context in error messages
- Test error conditions

For more examples, see the `examples/` directory and the test suite in `tests/`.
