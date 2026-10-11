//! Allocation-free UTF-16 traversal over UTF-8 and WTF-8.
const std = @import("std");
pub const Unit = struct { value: u16, bytes: []const u8, valid: bool = true };

pub const Cursor = struct {
    data: []const u8,
    offset: usize = 0,
    pending: ?Unit = null,

    pub fn next(self: *Cursor) ?Unit {
        if (self.pending) |unit| {
            self.pending = null;
            return unit;
        }
        if (self.offset >= self.data.len) return null;
        const start = self.offset;
        const n = std.unicode.utf8ByteSequenceLength(self.data[start]) catch {
            self.offset += 1;
            return .{ .value = self.data[start], .bytes = self.data[start..][0..1], .valid = false };
        };
        if (n > self.data.len - start) {
            self.offset = self.data.len;
            return .{ .value = self.data[start], .bytes = self.data[start..], .valid = false };
        }
        const bytes = self.data[start..][0..n];
        const cp = std.unicode.utf8Decode(bytes) catch blk: {
            if (n == 3 and bytes[0] == 0xed and bytes[1] >= 0xa0 and bytes[1] <= 0xbf and bytes[2] & 0xc0 == 0x80)
                break :blk (@as(u21, bytes[0] & 15) << 12) | (@as(u21, bytes[1] & 63) << 6) | (bytes[2] & 63);
            self.offset += 1;
            return .{ .value = bytes[0], .bytes = bytes[0..1], .valid = false };
        };
        self.offset += n;
        if (cp <= 0xffff) return .{ .value = @intCast(cp), .bytes = bytes };
        const adjusted = cp - 0x10000;
        self.pending = .{ .value = @intCast(0xdc00 + (adjusted & 1023)), .bytes = bytes };
        return .{ .value = @intCast(0xd800 + (adjusted >> 10)), .bytes = bytes };
    }

    pub fn skip(self: *Cursor, count: usize) void {
        for (0..count) |_| _ = self.next() orelse break;
    }
};

/// Borrowed input; next() yields a full code point or an isolated surrogate.
pub const Iterator = struct {
    cursor: Cursor,
    pub fn next(self: *Iterator) ?u21 {
        const first = self.cursor.next() orelse return null;
        if (first.value >= 0xd800 and first.value <= 0xdbff) {
            var lookahead = self.cursor;
            if (lookahead.next()) |second| {
                if (second.value >= 0xdc00 and second.value <= 0xdfff) {
                    self.cursor = lookahead;
                    return 0x10000 + (@as(u21, first.value - 0xd800) << 10) + second.value - 0xdc00;
                }
            }
        }
        return first.value;
    }
};

pub fn eql(a: []const u8, b: []const u8) bool {
    if (std.mem.eql(u8, a, b)) return true;
    // Invalid non-WTF-8 bytes retain their historical byte-wise identity.
    var left: Cursor = .{ .data = a };
    var right: Cursor = .{ .data = b };
    while (left.next()) |x| {
        const y = right.next() orelse return false;
        if (x.value != y.value or x.valid != y.valid) return false;
        if (!x.valid and !std.mem.eql(u8, x.bytes, y.bytes)) return false;
    }
    return right.next() == null;
}

pub const Builder = struct {
    allocator: std.mem.Allocator,
    list: std.ArrayList(u8) = .empty,
    pub fn deinit(self: *Builder) void {
        self.list.deinit(self.allocator);
    }
    pub fn finish(self: *Builder) ![]u8 {
        return self.list.toOwnedSlice(self.allocator);
    }
    pub fn append(self: *Builder, cp: u21) std.mem.Allocator.Error!void {
        if (cp >= 0xdc00 and cp <= 0xdfff and self.list.items.len >= 3) {
            const tail = self.list.items[self.list.items.len - 3 ..];
            if (tail[0] == 0xed and tail[1] >= 0xa0 and tail[1] <= 0xaf and tail[2] & 0xc0 == 0x80) {
                const high: u21 = (@as(u21, tail[0] & 15) << 12) | (@as(u21, tail[1] & 63) << 6) | (tail[2] & 63);
                var buf: [4]u8 = undefined;
                const n = std.unicode.utf8Encode(0x10000 + ((high - 0xd800) << 10) + cp - 0xdc00, &buf) catch unreachable;
                // Reserve before removing bytes, so an allocation failure is atomic.
                try self.list.ensureUnusedCapacity(self.allocator, 1);
                self.list.items.len -= 3;
                self.list.appendSliceAssumeCapacity(buf[0..n]);
                return;
            }
        }
        var buf: [4]u8 = undefined;
        if (cp >= 0xd800 and cp <= 0xdfff) {
            buf[0] = 0xe0 | @as(u8, @intCast(cp >> 12));
            buf[1] = 0x80 | @as(u8, @intCast((cp >> 6) & 63));
            buf[2] = 0x80 | @as(u8, @intCast(cp & 63));
            try self.list.appendSlice(self.allocator, buf[0..3]);
        } else {
            const n = std.unicode.utf8Encode(cp, &buf) catch unreachable;
            try self.list.appendSlice(self.allocator, buf[0..n]);
        }
    }
    pub fn appendUnit(self: *Builder, unit: Unit) !void {
        if (unit.valid) try self.append(unit.value) else try self.list.appendSlice(self.allocator, unit.bytes);
    }
    pub fn appendString(self: *Builder, data: []const u8) !void {
        if (std.unicode.utf8ValidateSlice(data)) {
            try self.list.appendSlice(self.allocator, data);
            return;
        }
        var cursor: Cursor = .{ .data = data };
        while (cursor.next()) |unit| try self.appendUnit(unit);
    }
};

pub fn range(allocator: std.mem.Allocator, data: []const u8, start: usize, end: usize) ![]u8 {
    if (end <= start) return allocator.alloc(u8, 0);
    var cursor: Cursor = .{ .data = data };
    cursor.skip(start);
    var stop = cursor;
    stop.skip(end - start);
    const byte_start = cursor.offset;
    const byte_end = if (stop.pending) |low| stop.offset - low.bytes.len else stop.offset;
    const prefix: usize = if (cursor.pending != null) 3 else 0;
    const suffix: usize = if (stop.pending != null) 3 else 0;
    const total = @addWithOverflow(byte_end - byte_start, prefix + suffix);
    if (total[1] != 0) return error.OutOfMemory;
    const out = try allocator.alloc(u8, total[0]);
    if (cursor.pending) |low| encodeHalf(out[0..3], low.value);
    @memcpy(out[prefix..][0 .. byte_end - byte_start], data[byte_start..byte_end]);
    if (stop.pending) |low| {
        const cp = std.unicode.utf8Decode(low.bytes) catch unreachable;
        encodeHalf(out[out.len - 3 ..], @intCast(0xd800 + ((cp - 0x10000) >> 10)));
    }
    return out;
}

fn encodeHalf(out: []u8, value: u16) void {
    out[0] = 0xe0 | @as(u8, @intCast(value >> 12));
    out[1] = 0x80 | @as(u8, @intCast((value >> 6) & 63));
    out[2] = 0x80 | @as(u8, @intCast(value & 63));
}

pub fn isAscii(data: []const u8) bool {
    for (data) |byte| if (byte >= 128) return false;
    return true;
}

/// Compare at an arbitrary UTF-16 boundary without allocating.
pub fn matches(position: Cursor, needle: []const u8) bool {
    var haystack = position;
    var pattern: Cursor = .{ .data = needle };
    while (pattern.next()) |a| {
        const b = haystack.next() orelse return false;
        if (a.value != b.value or a.valid != b.valid) return false;
        if (!a.valid and !std.mem.eql(u8, a.bytes, b.bytes)) return false;
    }
    return true;
}
