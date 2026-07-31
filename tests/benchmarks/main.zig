const std = @import("std");
const zstring = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    std.debug.print("z-string Benchmarks\n", .{});
    std.debug.print("===================\n\n", .{});

    // Benchmark: lengthUtf16
    benchmarkLengthUtf16(io);

    // Benchmark: utf16IndexToByte
    benchmarkUtf16IndexToByte(io);
}

fn benchmarkLengthUtf16(io: std.Io) void {
    const iterations: usize = 1_000_000;

    const test_strings = [_][]const u8{
        "hello",
        "hello world this is a longer string",
        "café résumé",
        "😀😃😄😁😆😅",
        "混合content with emojis😀and中文",
    };

    std.debug.print("Benchmark: lengthUtf16\n", .{});
    std.debug.print("-----------------------\n", .{});

    for (test_strings) |str| {
        const start = std.Io.Timestamp.now(io, .awake);

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            _ = zstring.utf16.lengthUtf16(str);
        }

        const elapsed_ns = std.Io.Timestamp.now(io, .awake).nanoseconds - start.nanoseconds;
        const ns_per_op = @divTrunc(elapsed_ns, iterations);

        std.debug.print("  '{s}' ({} bytes): {} ns/op\n", .{ str, str.len, ns_per_op });
    }

    std.debug.print("\n", .{});
}

fn benchmarkUtf16IndexToByte(io: std.Io) void {
    const iterations: usize = 1_000_000;
    const str = "hello😀world";

    std.debug.print("Benchmark: utf16IndexToByte\n", .{});
    std.debug.print("----------------------------\n", .{});

    const start = std.Io.Timestamp.now(io, .awake);

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = zstring.utf16.utf16IndexToByte(str, 5) catch unreachable;
    }

    const elapsed_ns = std.Io.Timestamp.now(io, .awake).nanoseconds - start.nanoseconds;
    const ns_per_op = @divTrunc(elapsed_ns, iterations);

    std.debug.print("  String: '{s}'\n", .{str});
    std.debug.print("  Index: 5\n", .{});
    std.debug.print("  Time: {} ns/op\n", .{ns_per_op});
    std.debug.print("\n", .{});
}
