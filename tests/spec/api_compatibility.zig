const std = @import("std");
const z = @import("zstring");
// Public parameter types and result payloads frozen from commit ee08516.
fn check(comptime F: type, comptime parameters: anytype, comptime result: type, comptime fallible: bool) void {
    const f = @typeInfo(F).@"fn";
    if (f.param_types.len != parameters.len) @compileError("API parameter count changed");
    inline for (parameters, f.param_types) |expected, actual| {
        if (actual.? != expected) @compileError("API parameter type changed");
    }
    const ret = f.return_type.?;
    if (fallible) {
        if (@typeInfo(ret).error_union.payload != result) @compileError("API result changed");
    } else if (ret != result) @compileError("API result changed");
}
test "compatibility - every original public signature is preserved" {
    comptime {
        check(@TypeOf(z.ZString.init), .{[]const u8}, z.ZString, false);
        check(@TypeOf(z.ZString.initOwned), .{ std.mem.Allocator, []const u8 }, z.ZString, true);
        check(@TypeOf(z.ZString.fromOwned), .{ std.mem.Allocator, []const u8 }, z.ZString, false);
        check(@TypeOf(z.ZString.fromCharCode), .{ std.mem.Allocator, []const u16 }, z.ZString, true);
        check(@TypeOf(z.ZString.fromCodePoint), .{ std.mem.Allocator, []const u21 }, z.ZString, true);
        check(@TypeOf(z.ZString.deinit), .{*z.ZString}, void, false);
        check(@TypeOf(z.ZString.length), .{*z.ZString}, usize, false);
        check(@TypeOf(z.ZString.lengthConst), .{z.ZString}, usize, false);
        check(@TypeOf(z.ZString.byteLength), .{z.ZString}, usize, false);
        check(@TypeOf(z.ZString.isEmpty), .{z.ZString}, bool, false);
        check(@TypeOf(z.ZString.isOwned), .{z.ZString}, bool, false);
        check(@TypeOf(z.ZString.isWellFormed), .{z.ZString}, bool, false);
        check(@TypeOf(z.ZString.clone), .{ z.ZString, std.mem.Allocator }, z.ZString, true);
        check(@TypeOf(z.ZString.eql), .{ z.ZString, z.ZString }, bool, false);
        check(@TypeOf(z.ZString.eqlSlice), .{ z.ZString, []const u8 }, bool, false);
        check(@TypeOf(z.ZString.charAt), .{ z.ZString, std.mem.Allocator, isize }, []u8, true);
        check(@TypeOf(z.ZString.at), .{ z.ZString, std.mem.Allocator, isize }, ?[]u8, true);
        check(@TypeOf(z.ZString.charCodeAt), .{ z.ZString, isize }, ?u16, false);
        check(@TypeOf(z.ZString.codePointAt), .{ z.ZString, isize }, ?u21, false);
        check(@TypeOf(z.ZString.indexOf), .{ z.ZString, []const u8, ?isize }, isize, false);
        check(@TypeOf(z.ZString.lastIndexOf), .{ z.ZString, []const u8, ?isize }, isize, false);
        check(@TypeOf(z.ZString.includes), .{ z.ZString, []const u8, ?isize }, bool, false);
        check(@TypeOf(z.ZString.startsWith), .{ z.ZString, []const u8, ?isize }, bool, false);
        check(@TypeOf(z.ZString.endsWith), .{ z.ZString, []const u8, ?isize }, bool, false);
        check(@TypeOf(z.ZString.slice), .{ z.ZString, std.mem.Allocator, isize, ?isize }, []u8, true);
        check(@TypeOf(z.ZString.substring), .{ z.ZString, std.mem.Allocator, isize, ?isize }, []u8, true);
        check(@TypeOf(z.ZString.concat), .{ z.ZString, std.mem.Allocator, []const []const u8 }, []u8, true);
        check(@TypeOf(z.ZString.repeat), .{ z.ZString, std.mem.Allocator, isize }, []u8, true);
        check(@TypeOf(z.ZString.padStart), .{ z.ZString, std.mem.Allocator, isize, ?[]const u8 }, []u8, true);
        check(@TypeOf(z.ZString.padEnd), .{ z.ZString, std.mem.Allocator, isize, ?[]const u8 }, []u8, true);
        check(@TypeOf(z.ZString.trim), .{ z.ZString, std.mem.Allocator }, []u8, true);
        check(@TypeOf(z.ZString.trimStart), .{ z.ZString, std.mem.Allocator }, []u8, true);
        check(@TypeOf(z.ZString.trimEnd), .{ z.ZString, std.mem.Allocator }, []u8, true);
        check(@TypeOf(z.ZString.split), .{ z.ZString, std.mem.Allocator, ?[]const u8, ?usize }, [][]u8, true);
        check(@TypeOf(z.ZString.freeSplitResult), .{ std.mem.Allocator, [][]u8 }, void, false);
        check(@TypeOf(z.ZString.splitRegex), .{ z.ZString, std.mem.Allocator, []const u8, ?usize }, [][]u8, true);
        check(@TypeOf(z.ZString.toLowerCase), .{ z.ZString, std.mem.Allocator }, []u8, true);
        check(@TypeOf(z.ZString.toUpperCase), .{ z.ZString, std.mem.Allocator }, []u8, true);
        check(@TypeOf(z.ZString.toLocaleLowerCase), .{ z.ZString, std.mem.Allocator, ?[]const u8 }, []u8, true);
        check(@TypeOf(z.ZString.toLocaleUpperCase), .{ z.ZString, std.mem.Allocator, ?[]const u8 }, []u8, true);
        check(@TypeOf(z.ZString.toStringAlloc), .{ z.ZString, std.mem.Allocator }, []u8, true);
        check(@TypeOf(z.ZString.valueOfAlloc), .{ z.ZString, std.mem.Allocator }, []u8, true);
        check(@TypeOf(z.ZString.localeCompare), .{ z.ZString, []const u8, ?[]const u8, ?[]const u8 }, isize, false);
        check(@TypeOf(z.ZString.normalize), .{ z.ZString, std.mem.Allocator, ?[]const u8 }, []u8, true);
        check(@TypeOf(z.ZString.searchRegex), .{ z.ZString, std.mem.Allocator, []const u8 }, isize, true);
        check(@TypeOf(z.ZString.matchRegex), .{ z.ZString, std.mem.Allocator, []const u8 }, ?z.regex.MatchArray, true);
        check(@TypeOf(z.ZString.matchAllRegex), .{ z.ZString, std.mem.Allocator, []const u8 }, []z.regex.MatchArray, true);
        check(@TypeOf(z.ZString.freeMatchAllResult), .{ std.mem.Allocator, []z.regex.MatchArray }, void, false);
        check(@TypeOf(z.ZString.replaceRegex), .{ z.ZString, std.mem.Allocator, []const u8, []const u8 }, []const u8, true);
        check(@TypeOf(z.ZString.replaceAllRegex), .{ z.ZString, std.mem.Allocator, []const u8, []const u8 }, []const u8, true);
        check(@TypeOf(z.utf16.encodeSurrogateWtf8), .{ *[3]u8, u16 }, void, false);
        check(@TypeOf(z.utf16.decodeSurrogateWtf8), .{[]const u8}, ?u16, false);
        check(@TypeOf(z.utf16.concatUtf8), .{ std.mem.Allocator, []const u8, []const u8 }, []u8, true);
        check(@TypeOf(z.utf16.mergeSurrogateBoundary), .{ []const u8, []const u8 }, ?[4]u8, false);
        check(@TypeOf(z.utf16.sanitizeWtf8ToUtf8), .{ std.mem.Allocator, []const u8 }, []u8, true);
        check(@TypeOf(z.utf16.lengthUtf16), .{[]const u8}, usize, false);
        check(@TypeOf(z.utf16.byteIndexToUtf16), .{ []const u8, usize }, usize, true);
        check(@TypeOf(z.utf16.utf16IndexToBytePos), .{ []const u8, usize }, z.utf16.Utf16Position, true);
        check(@TypeOf(z.utf16.utf16IndexToByte), .{ []const u8, usize }, usize, true);
        check(@TypeOf(z.utf16.utf16IndexFromEndToByte), .{ []const u8, usize }, usize, true);
        check(@TypeOf(z.utf16.utf16IndexFromEndToBytePos), .{ []const u8, usize }, z.utf16.Utf16Position, true);
        check(@TypeOf(z.utf16.codeUnitAt), .{ []const u8, usize }, u16, true);
        check(@TypeOf(z.access.charAt), .{ std.mem.Allocator, []const u8, isize }, []u8, true);
        check(@TypeOf(z.access.extractCodeUnit), .{ std.mem.Allocator, []const u8, usize, bool }, ?[]u8, true);
        check(@TypeOf(z.access.at), .{ std.mem.Allocator, []const u8, isize }, ?[]u8, true);
        check(@TypeOf(z.access.charCodeAt), .{ []const u8, isize }, ?u16, false);
        check(@TypeOf(z.access.codePointAt), .{ []const u8, isize }, ?u21, false);
        check(@TypeOf(z.search.indexOf), .{ []const u8, []const u8, ?isize }, isize, false);
        check(@TypeOf(z.search.lastIndexOf), .{ []const u8, []const u8, ?isize }, isize, false);
        check(@TypeOf(z.search.includes), .{ []const u8, []const u8, ?isize }, bool, false);
        check(@TypeOf(z.search.startsWith), .{ []const u8, []const u8, ?isize }, bool, false);
        check(@TypeOf(z.search.endsWith), .{ []const u8, []const u8, ?isize }, bool, false);
        check(@TypeOf(z.transform.slice), .{ std.mem.Allocator, []const u8, isize, ?isize }, []u8, true);
        check(@TypeOf(z.transform.substring), .{ std.mem.Allocator, []const u8, isize, ?isize }, []u8, true);
        check(@TypeOf(z.transform.concat), .{ std.mem.Allocator, []const u8, []const []const u8 }, []u8, true);
        check(@TypeOf(z.transform.repeat), .{ std.mem.Allocator, []const u8, isize }, []u8, true);
        check(@TypeOf(z.padding.padStart), .{ std.mem.Allocator, []const u8, isize, ?[]const u8 }, []u8, true);
        check(@TypeOf(z.padding.padEnd), .{ std.mem.Allocator, []const u8, isize, ?[]const u8 }, []u8, true);
        check(@TypeOf(z.trimming.trim), .{ std.mem.Allocator, []const u8 }, []u8, true);
        check(@TypeOf(z.trimming.trimStart), .{ std.mem.Allocator, []const u8 }, []u8, true);
        check(@TypeOf(z.trimming.trimEnd), .{ std.mem.Allocator, []const u8 }, []u8, true);
        check(@TypeOf(z.split.split), .{ std.mem.Allocator, []const u8, ?[]const u8, ?usize }, [][]u8, true);
        check(@TypeOf(z.split.freeSplitResult), .{ std.mem.Allocator, [][]u8 }, void, false);
        check(@TypeOf(z.case.toLowerCase), .{ std.mem.Allocator, []const u8 }, []u8, true);
        check(@TypeOf(z.case.toUpperCase), .{ std.mem.Allocator, []const u8 }, []u8, true);
        check(@TypeOf(z.case.toLocaleLowerCase), .{ std.mem.Allocator, []const u8, ?[]const u8 }, []u8, true);
        check(@TypeOf(z.case.toLocaleUpperCase), .{ std.mem.Allocator, []const u8, ?[]const u8 }, []u8, true);
        check(@TypeOf(z.utility.toString), .{ std.mem.Allocator, []const u8 }, []u8, true);
        check(@TypeOf(z.utility.valueOf), .{ std.mem.Allocator, []const u8 }, []u8, true);
        check(@TypeOf(z.utility.localeCompare), .{ []const u8, []const u8, ?[]const u8, ?[]const u8 }, isize, false);
        check(@TypeOf(z.utility.normalize), .{ std.mem.Allocator, []const u8, ?[]const u8 }, []u8, true);
        check(@TypeOf(z.regex.search), .{ std.mem.Allocator, []const u8, []const u8 }, isize, true);
        check(@TypeOf(z.regex.MatchArray.deinit), .{z.regex.MatchArray}, void, false);
        check(@TypeOf(z.regex.match), .{ std.mem.Allocator, []const u8, []const u8 }, ?z.regex.MatchArray, true);
        check(@TypeOf(z.regex.matchAll), .{ std.mem.Allocator, []const u8, []const u8 }, []z.regex.MatchArray, true);
        check(@TypeOf(z.regex.freeMatchAll), .{ std.mem.Allocator, []z.regex.MatchArray }, void, false);
        check(@TypeOf(z.regex.replace), .{ std.mem.Allocator, []const u8, []const u8, []const u8 }, []const u8, true);
        check(@TypeOf(z.regex.replaceAll), .{ std.mem.Allocator, []const u8, []const u8, []const u8 }, []const u8, true);
        check(@TypeOf(z.regex.splitRegex), .{ std.mem.Allocator, []const u8, []const u8, ?usize }, [][]u8, true);
    }
}

fn checkErrors(comptime F: type, comptime expected: type) void {
    const R = @typeInfo(F).@"fn".return_type.?;
    const actual = if (@typeInfo(R) == .error_union) @typeInfo(R).error_union.error_set else error{};
    const actual_members = @typeInfo(actual).error_set.error_names.?;
    const expected_members = @typeInfo(expected).error_set.error_names.?;
    if (actual_members.len != expected_members.len) @compileError("Original public error set changed: " ++ @typeName(actual));
    for (actual_members) |member| {
        var found = false;
        for (expected_members) |old| if (std.mem.eql(u8, member, old)) {
            found = true;
        };
        if (!found) @compileError("Unexpected public error: " ++ member);
    }
}

test "compatibility - original error sets and aliases are preserved" {
    comptime {
        checkErrors(@TypeOf(z.ZString.init), error{});
        checkErrors(@TypeOf(z.ZString.initOwned), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.fromOwned), error{});
        checkErrors(@TypeOf(z.ZString.fromCharCode), error{
            OutOfMemory,
            DanglingSurrogateHalf,
            ExpectedSecondSurrogateHalf,
            UnexpectedSecondSurrogateHalf,
        });
        checkErrors(@TypeOf(z.ZString.fromCodePoint), error{
            OutOfMemory,
            Utf8CannotEncodeSurrogateHalf,
            CodepointTooLarge,
        });
        checkErrors(@TypeOf(z.ZString.deinit), error{});
        checkErrors(@TypeOf(z.ZString.length), error{});
        checkErrors(@TypeOf(z.ZString.lengthConst), error{});
        checkErrors(@TypeOf(z.ZString.byteLength), error{});
        checkErrors(@TypeOf(z.ZString.isEmpty), error{});
        checkErrors(@TypeOf(z.ZString.isOwned), error{});
        checkErrors(@TypeOf(z.ZString.isWellFormed), error{});
        checkErrors(@TypeOf(z.ZString.clone), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.eql), error{});
        checkErrors(@TypeOf(z.ZString.eqlSlice), error{});
        checkErrors(@TypeOf(z.ZString.charAt), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.at), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.charCodeAt), error{});
        checkErrors(@TypeOf(z.ZString.codePointAt), error{});
        checkErrors(@TypeOf(z.ZString.indexOf), error{});
        checkErrors(@TypeOf(z.ZString.lastIndexOf), error{});
        checkErrors(@TypeOf(z.ZString.includes), error{});
        checkErrors(@TypeOf(z.ZString.startsWith), error{});
        checkErrors(@TypeOf(z.ZString.endsWith), error{});
        checkErrors(@TypeOf(z.ZString.slice), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.substring), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.concat), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.repeat), error{
            OutOfMemory,
            InvalidCount,
        });
        checkErrors(@TypeOf(z.ZString.padStart), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.padEnd), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.trim), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.trimStart), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.trimLeft), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.trimEnd), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.trimRight), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.split), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.freeSplitResult), error{});
        checkErrors(@TypeOf(z.ZString.splitRegex), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.toLowerCase), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.toUpperCase), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.toLocaleLowerCase), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.toLocaleUpperCase), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.toStringAlloc), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.valueOfAlloc), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.localeCompare), error{});
        checkErrors(@TypeOf(z.ZString.normalize), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.searchRegex), error{});
        checkErrors(@TypeOf(z.ZString.matchRegex), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.matchAllRegex), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.freeMatchAllResult), error{});
        checkErrors(@TypeOf(z.ZString.replaceRegex), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.ZString.replaceAllRegex), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.utf16.encodeSurrogateWtf8), error{});
        checkErrors(@TypeOf(z.utf16.decodeSurrogateWtf8), error{});
        checkErrors(@TypeOf(z.utf16.concatUtf8), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.utf16.mergeSurrogateBoundary), error{});
        checkErrors(@TypeOf(z.utf16.sanitizeWtf8ToUtf8), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.utf16.lengthUtf16), error{});
        checkErrors(@TypeOf(z.utf16.byteIndexToUtf16), error{
            InvalidUtf8,
            InvalidUtf16,
            IndexOutOfBounds,
            InvalidCodePoint,
        });
        checkErrors(@TypeOf(z.utf16.utf16IndexToBytePos), error{
            InvalidUtf8,
            InvalidUtf16,
            IndexOutOfBounds,
            InvalidCodePoint,
        });
        checkErrors(@TypeOf(z.utf16.utf16IndexToByte), error{
            InvalidUtf8,
            InvalidUtf16,
            IndexOutOfBounds,
            InvalidCodePoint,
        });
        checkErrors(@TypeOf(z.utf16.utf16IndexFromEndToByte), error{
            InvalidUtf8,
            InvalidUtf16,
            IndexOutOfBounds,
            InvalidCodePoint,
        });
        checkErrors(@TypeOf(z.utf16.utf16IndexFromEndToBytePos), error{
            InvalidUtf8,
            InvalidUtf16,
            IndexOutOfBounds,
            InvalidCodePoint,
        });
        checkErrors(@TypeOf(z.utf16.codeUnitAt), error{
            InvalidUtf8,
            InvalidUtf16,
            IndexOutOfBounds,
            InvalidCodePoint,
        });
        checkErrors(@TypeOf(z.access.charAt), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.access.extractCodeUnit), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.access.at), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.access.charCodeAt), error{});
        checkErrors(@TypeOf(z.access.codePointAt), error{});
        checkErrors(@TypeOf(z.search.indexOf), error{});
        checkErrors(@TypeOf(z.search.lastIndexOf), error{});
        checkErrors(@TypeOf(z.search.includes), error{});
        checkErrors(@TypeOf(z.search.startsWith), error{});
        checkErrors(@TypeOf(z.search.endsWith), error{});
        checkErrors(@TypeOf(z.transform.slice), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.transform.substring), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.transform.concat), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.transform.repeat), error{
            OutOfMemory,
            InvalidCount,
        });
        checkErrors(@TypeOf(z.padding.padStart), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.padding.padEnd), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.trimming.trim), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.trimming.trimStart), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.trimming.trimLeft), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.trimming.trimEnd), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.trimming.trimRight), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.split.split), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.split.freeSplitResult), error{});
        checkErrors(@TypeOf(z.case.toLowerCase), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.case.toUpperCase), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.case.toLocaleLowerCase), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.case.toLocaleUpperCase), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.utility.toString), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.utility.valueOf), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.utility.localeCompare), error{});
        checkErrors(@TypeOf(z.utility.normalize), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.regex.search), error{});
        checkErrors(@TypeOf(z.regex.match), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.regex.matchAll), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.regex.freeMatchAll), error{});
        checkErrors(@TypeOf(z.regex.replace), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.regex.replaceAll), error{
            OutOfMemory,
        });
        checkErrors(@TypeOf(z.regex.splitRegex), error{
            OutOfMemory,
        });
    }
    try std.testing.expectEqual(@as(usize, 3), @typeInfo(z.ZString).@"struct".field_names.len);
    try std.testing.expectEqual(@as(usize, 5), @typeInfo(z.regex.MatchArray).@"struct".field_names.len);
}
