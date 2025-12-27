/// C API for z-string
///
/// This module provides a C-compatible API for the z-string library.
/// It exposes all ECMAScript String methods through C functions.
///
/// Build instructions:
///   zig build-lib src/c_api.zig -O ReleaseFast        # Static library
///   zig build-lib src/c_api.zig -O ReleaseFast -dynamic  # Shared library
///
/// Usage from C:
///   #include "zstring.h"
///   gcc your_program.c -I./include -L. -lzstring -o your_program
///
/// Usage from C++:
///   #include "zstring.hpp"
///   g++ -std=c++17 your_program.cpp -I./include -L. -lzstring -o your_program

const std = @import("std");
const zstring = @import("zstring.zig");

/// Error codes for C API
pub const ZStringError = enum(c_int) {
    ZSTRING_OK = 0,
    ZSTRING_ERROR_OUT_OF_MEMORY = 1,
    ZSTRING_ERROR_INVALID_UTF8 = 2,
    ZSTRING_ERROR_INDEX_OUT_OF_BOUNDS = 3,
    ZSTRING_ERROR_INVALID_ARGUMENT = 4,
    ZSTRING_ERROR_REGEX_COMPILE = 5,
    ZSTRING_ERROR_REGEX_MATCH = 6,
};

/// Opaque handle to ZString
pub const ZString = extern struct {
    data: [*]const u8,
    len: usize,
};

/// Array of strings result
pub const ZStringArray = extern struct {
    items: [*c][*c]u8,
    count: usize,
};

// Global allocator for C API
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

/// Initialize a new ZString from a C string
export fn zstring_init(str: [*c]const u8, out: *?*ZString) ZStringError {
    if (str == null) return .ZSTRING_ERROR_INVALID_ARGUMENT;
    if (out == null) return .ZSTRING_ERROR_INVALID_ARGUMENT;

    const c_str = std.mem.span(str);

    // Validate UTF-8
    if (!std.unicode.utf8ValidateSlice(c_str)) {
        return .ZSTRING_ERROR_INVALID_UTF8;
    }

    // Allocate handle
    const handle = allocator.create(ZString) catch {
        return .ZSTRING_ERROR_OUT_OF_MEMORY;
    };

    // Duplicate string data
    const data_copy = allocator.dupe(u8, c_str) catch {
        allocator.destroy(handle);
        return .ZSTRING_ERROR_OUT_OF_MEMORY;
    };

    handle.* = .{
        .data = data_copy.ptr,
        .len = data_copy.len,
    };

    out.* = handle;
    return .ZSTRING_OK;
}

/// Free a ZString
export fn zstring_free(zstr: ?*ZString) void {
    if (zstr) |handle| {
        const slice = handle.data[0..handle.len];
        allocator.free(slice);
        allocator.destroy(handle);
    }
}

/// Get the UTF-16 length
export fn zstring_length(zstr: ?*const ZString) usize {
    if (zstr) |handle| {
        const str_obj = zstring.ZString.init(handle.data[0..handle.len]);
        return str_obj.length();
    }
    return 0;
}

/// Get raw UTF-8 bytes (borrowed)
export fn zstring_bytes(zstr: ?*const ZString) [*c]const u8 {
    if (zstr) |handle| {
        return handle.data;
    }
    return null;
}

/// Free a string allocated by zstring functions
export fn zstring_str_free(str: [*c]u8) void {
    if (str != null) {
        const slice = std.mem.span(str);
        allocator.free(slice);
    }
}

/// Free a ZStringArray
export fn zstring_array_free(array: *ZStringArray) void {
    if (array.items != null) {
        for (0..array.count) |i| {
            if (array.items[i] != null) {
                const slice = std.mem.span(array.items[i]);
                allocator.free(slice);
            }
        }
        allocator.free(array.items[0..array.count]);
    }
    array.* = .{
        .items = null,
        .count = 0,
    };
}

// ============================================================================
// Character Access Methods
// ============================================================================

/// Get character at index
export fn zstring_char_at(zstr: ?*const ZString, index: usize, out: *?[*c]u8) ZStringError {
    if (zstr == null or out == null) return .ZSTRING_ERROR_INVALID_ARGUMENT;

    const handle = zstr.?;
    const str_obj = zstring.ZString.init(handle.data[0..handle.len]);

    const result = str_obj.charAt(allocator, index) catch |err| {
        return switch (err) {
            error.OutOfMemory => .ZSTRING_ERROR_OUT_OF_MEMORY,
            error.IndexOutOfBounds => .ZSTRING_ERROR_INDEX_OUT_OF_BOUNDS,
            else => .ZSTRING_ERROR_INVALID_ARGUMENT,
        };
    };

    // Add null terminator for C
    const c_str = allocator.dupeZ(u8, result) catch {
        allocator.free(result);
        return .ZSTRING_ERROR_OUT_OF_MEMORY;
    };
    allocator.free(result);

    out.* = c_str.ptr;
    return .ZSTRING_OK;
}

/// Get character at index with negative indexing
export fn zstring_at(zstr: ?*const ZString, index: i64, out: *?[*c]u8) ZStringError {
    if (zstr == null or out == null) return .ZSTRING_ERROR_INVALID_ARGUMENT;

    const handle = zstr.?;
    const str_obj = zstring.ZString.init(handle.data[0..handle.len]);

    const maybe_result = str_obj.at(allocator, index) catch |err| {
        return switch (err) {
            error.OutOfMemory => .ZSTRING_ERROR_OUT_OF_MEMORY,
            else => .ZSTRING_ERROR_INVALID_ARGUMENT,
        };
    };

    if (maybe_result) |result| {
        defer allocator.free(result);
        const c_str = allocator.dupeZ(u8, result) catch {
            return .ZSTRING_ERROR_OUT_OF_MEMORY;
        };
        out.* = c_str.ptr;
    } else {
        out.* = null;
    }

    return .ZSTRING_OK;
}

// ============================================================================
// Search Methods
// ============================================================================

/// Find first occurrence
export fn zstring_index_of(zstr: ?*const ZString, search_str: [*c]const u8, position: i64) i64 {
    if (zstr == null or search_str == null) return -1;

    const handle = zstr.?;
    const str_obj = zstring.ZString.init(handle.data[0..handle.len]);
    const search = std.mem.span(search_str);

    const pos: ?usize = if (position >= 0) @intCast(position) else null;
    return str_obj.indexOf(search, pos);
}

/// Check if contains substring
export fn zstring_includes(zstr: ?*const ZString, search_str: [*c]const u8, position: i64) bool {
    if (zstr == null or search_str == null) return false;

    const handle = zstr.?;
    const str_obj = zstring.ZString.init(handle.data[0..handle.len]);
    const search = std.mem.span(search_str);

    const pos: ?usize = if (position >= 0) @intCast(position) else null;
    return str_obj.includes(search, pos);
}

// ============================================================================
// Transform Methods
// ============================================================================

/// Convert to uppercase
export fn zstring_to_upper_case(zstr: ?*const ZString, out: *?[*c]u8) ZStringError {
    if (zstr == null or out == null) return .ZSTRING_ERROR_INVALID_ARGUMENT;

    const handle = zstr.?;
    const str_obj = zstring.ZString.init(handle.data[0..handle.len]);

    const result = str_obj.toUpperCase(allocator) catch {
        return .ZSTRING_ERROR_OUT_OF_MEMORY;
    };

    const c_str = allocator.dupeZ(u8, result) catch {
        allocator.free(result);
        return .ZSTRING_ERROR_OUT_OF_MEMORY;
    };
    allocator.free(result);

    out.* = c_str.ptr;
    return .ZSTRING_OK;
}

/// Convert to lowercase
export fn zstring_to_lower_case(zstr: ?*const ZString, out: *?[*c]u8) ZStringError {
    if (zstr == null or out == null) return .ZSTRING_ERROR_INVALID_ARGUMENT;

    const handle = zstr.?;
    const str_obj = zstring.ZString.init(handle.data[0..handle.len]);

    const result = str_obj.toLowerCase(allocator) catch {
        return .ZSTRING_ERROR_OUT_OF_MEMORY;
    };

    const c_str = allocator.dupeZ(u8, result) catch {
        allocator.free(result);
        return .ZSTRING_ERROR_OUT_OF_MEMORY;
    };
    allocator.free(result);

    out.* = c_str.ptr;
    return .ZSTRING_OK;
}

/// Trim whitespace
export fn zstring_trim(zstr: ?*const ZString, out: *?[*c]u8) ZStringError {
    if (zstr == null or out == null) return .ZSTRING_ERROR_INVALID_ARGUMENT;

    const handle = zstr.?;
    const str_obj = zstring.ZString.init(handle.data[0..handle.len]);

    const result = str_obj.trim(allocator) catch {
        return .ZSTRING_ERROR_OUT_OF_MEMORY;
    };

    const c_str = allocator.dupeZ(u8, result) catch {
        allocator.free(result);
        return .ZSTRING_ERROR_OUT_OF_MEMORY;
    };
    allocator.free(result);

    out.* = c_str.ptr;
    return .ZSTRING_OK;
}

// ============================================================================
// Split Method
// ============================================================================

/// Split string into array
export fn zstring_split(zstr: ?*const ZString, separator: [*c]const u8, limit: usize, out: *ZStringArray) ZStringError {
    if (zstr == null or out == null) return .ZSTRING_ERROR_INVALID_ARGUMENT;

    const handle = zstr.?;
    const str_obj = zstring.ZString.init(handle.data[0..handle.len]);

    const sep: ?[]const u8 = if (separator != null) std.mem.span(separator) else null;
    const lim: ?usize = if (limit > 0) limit else null;

    const parts = str_obj.split(allocator, sep, lim) catch {
        return .ZSTRING_ERROR_OUT_OF_MEMORY;
    };
    defer zstring.ZString.freeSplitResult(allocator, parts);

    // Convert to C array
    const c_items = allocator.alloc([*c]u8, parts.len) catch {
        return .ZSTRING_ERROR_OUT_OF_MEMORY;
    };

    for (parts, 0..) |part, i| {
        const c_str = allocator.dupeZ(u8, part) catch {
            // Free already allocated items
            for (0..i) |j| {
                allocator.free(std.mem.span(c_items[j]));
            }
            allocator.free(c_items);
            return .ZSTRING_ERROR_OUT_OF_MEMORY;
        };
        c_items[i] = c_str.ptr;
    }

    out.* = .{
        .items = c_items.ptr,
        .count = parts.len,
    };

    return .ZSTRING_OK;
}

// NOTE: Additional methods (slice, substring, concat, repeat, padStart, padEnd,
// trimStart, trimEnd, charCodeAt, codePointAt, lastIndexOf, startsWith, endsWith,
// localeCompare, normalize, search, match, replace, replaceAll) can be implemented
// following the same pattern as above.
//
// The implementation would be similar:
// 1. Validate input parameters
// 2. Create ZString object from handle
// 3. Call the corresponding Zig method
// 4. Convert result to C-compatible format (null-terminated strings)
// 5. Return error code or result
//
// For production use, all methods from the header should be fully implemented.
