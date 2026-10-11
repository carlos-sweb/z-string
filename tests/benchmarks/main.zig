//! Ten warmed samples, consumed results, and separately measured allocations.
const std = @import("std");
const z = @import("zstring");
const Operation = enum { index_ascii, index_unicode, slice_half, split_wtf8, case_ascii, case_unicode, pad_unicode, normalize };
var checksum: usize = 0;

fn consume(bytes: []const u8) void {
    for (bytes) |byte| checksum +%= byte;
    std.mem.doNotOptimizeAway(bytes.ptr);
    std.mem.doNotOptimizeAway(checksum);
}
fn run(op: Operation, allocator: std.mem.Allocator, input: []const u8) !void {
    std.mem.doNotOptimizeAway(input.ptr);
    switch (op) {
        .index_ascii, .index_unicode => {
            const index = z.search.indexOf(input, "needle", null);
            std.mem.doNotOptimizeAway(index);
            checksum +%= @bitCast(index);
        },
        .split_wtf8 => {
            const parts = try z.split.split(allocator, input, "\xed\xa0\xbd", null);
            defer z.split.freeSplitResult(allocator, parts);
            for (parts) |part| consume(part);
        },
        else => {
            const bytes = switch (op) {
                .slice_half => try z.transform.slice(allocator, input, 1, 200),
                .case_ascii, .case_unicode => try z.case.toUpperCase(allocator, input),
                .pad_unicode => try z.padding.padStart(allocator, input, 200, "😀"),
                .normalize => try z.utility.normalize(allocator, input, "NFC"),
                else => unreachable,
            };
            defer allocator.free(bytes);
            consume(bytes);
        },
    }
}
pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.smp_allocator;
    const ascii = try allocator.alloc(u8, 1024);
    defer allocator.free(ascii);
    @memset(ascii, 'a');
    @memcpy(ascii[1000..][0..6], "needle");
    const emoji = try allocator.alloc(u8, 1024);
    defer allocator.free(emoji);
    for (0..256) |i| @memcpy(emoji[i * 4 ..][0..4], "😀");
    const mixed = try allocator.dupe(u8, "混合 café 😀 needle");
    defer allocator.free(mixed);
    const cases = .{ .{ Operation.index_ascii, ascii }, .{ Operation.index_unicode, mixed }, .{ Operation.slice_half, emoji }, .{ Operation.split_wtf8, emoji }, .{ Operation.case_ascii, ascii }, .{ Operation.case_unicode, "Straße İ ΟΣ 𐐨 ﬃ" }, .{ Operation.pad_unicode, "x" }, .{ Operation.normalize, "s\u{0307}\u{0323} e\u{0301} 가 ﬁ" } };
    std.debug.print("operation,median_ns_per_op,min_ns_per_op,max_ns_per_op,allocations,requested_bytes\n", .{});
    inline for (cases) |case| {
        const op = case[0];
        const input = case[1];
        const iterations: usize = if (op == .index_ascii or op == .index_unicode) 100_000 else 1000;
        for (0..100) |_| try run(op, allocator, input);
        var samples: [10]u64 = undefined;
        for (&samples) |*sample| {
            const start = std.Io.Timestamp.now(init.io, .awake);
            for (0..iterations) |_| try run(op, allocator, input);
            const elapsed = std.Io.Timestamp.now(init.io, .awake).nanoseconds - start.nanoseconds;
            sample.* = @intCast(@divTrunc(elapsed, iterations));
        }
        std.mem.sort(u64, &samples, {}, std.sort.asc(u64));
        var counts = std.testing.FailingAllocator.init(allocator, .{});
        try run(op, counts.allocator(), input);
        std.debug.assert(counts.allocated_bytes == counts.freed_bytes);
        std.debug.print("{s},{d},{d},{d},{d},{d}\n", .{ @tagName(op), (samples[4] + samples[5]) / 2, samples[0], samples[9], counts.allocations, counts.allocated_bytes });
    }
    std.debug.print("checksum={d}\n", .{checksum});
}
