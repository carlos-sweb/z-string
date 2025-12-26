const std = @import("std");
const zstring = @import("zstring");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("z-string Benchmarks\n", .{});
    try stdout.print("===================\n\n", .{});

    // Benchmark: lengthUtf16
    try benchmarkLengthUtf16(stdout);

    // Benchmark: utf16IndexToByte
    try benchmarkUtf16IndexToByte(stdout);
}

fn benchmarkLengthUtf16(writer: anytype) !void {
    const iterations: usize = 1_000_000;

    const test_strings = [_][]const u8{
        "hello",
        "hello world this is a longer string",
        "café résumé",
        "😀😃😄😁😆😅",
        "混合content with emojis😀and中文",
    };

    try writer.print("Benchmark: lengthUtf16\n", .{});
    try writer.print("-----------------------\n", .{});

    for (test_strings) |str| {
        var timer = try std.time.Timer.start();

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            _ = zstring.utf16.lengthUtf16(str);
        }

        const elapsed_ns = timer.read();
        const ns_per_op = elapsed_ns / iterations;

        try writer.print("  '{s}' ({} bytes): {} ns/op\n", .{ str, str.len, ns_per_op });
    }

    try writer.print("\n", .{});
}

fn benchmarkUtf16IndexToByte(writer: anytype) !void {
    const iterations: usize = 1_000_000;
    const str = "hello😀world";

    try writer.print("Benchmark: utf16IndexToByte\n", .{});
    try writer.print("----------------------------\n", .{});

    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = zstring.utf16.utf16IndexToByte(str, 5) catch unreachable;
    }

    const elapsed_ns = timer.read();
    const ns_per_op = elapsed_ns / iterations;

    try writer.print("  String: '{s}'\n", .{str});
    try writer.print("  Index: 5\n", .{});
    try writer.print("  Time: {} ns/op\n", .{ns_per_op});
    try writer.print("\n", .{});
}
