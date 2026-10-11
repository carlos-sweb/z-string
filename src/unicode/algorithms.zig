//! Unicode data lookup, decomposition and allocation-free canonical comparison.
const std = @import("std");
const data = @import("data.zig");
const units = @import("../core/units.zig");
pub const version = data.version;

pub fn lookup(comptime T: type, table: []const T, cp: u21) ?T {
    var lo: usize = 0;
    var hi = table.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (table[mid].cp < cp) lo = mid + 1 else hi = mid;
    }
    if (lo < table.len and table[lo].cp == cp) return table[lo];
    return null;
}

pub fn combiningClass(cp: u21) u8 {
    return if (lookup(data.Combining, &data.combining, cp)) |entry| entry.value else 0;
}

pub fn inRanges(table: []const data.Range, cp: u21) bool {
    var lo: usize = 0;
    var hi = table.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (table[mid].last < cp) lo = mid + 1 else hi = mid;
    }
    return lo < table.len and table[lo].first <= cp;
}

pub fn isCased(cp: u21) bool {
    return inRanges(&data.cased, cp);
}
pub fn isCaseIgnorable(cp: u21) bool {
    return inRanges(&data.case_ignorable, cp);
}

/// Maximum recursive expansion is 18 code points in the pinned Unicode data.
pub fn decompose(cp: u21, compatibility: bool, buffer: *[18]u21, len: *usize) void {
    if (cp >= 0xac00 and cp < 0xac00 + 11172) {
        const index = cp - 0xac00;
        buffer[len.*] = 0x1100 + index / 588;
        buffer[len.* + 1] = 0x1161 + (index % 588) / 28;
        len.* += 2;
        if (index % 28 != 0) {
            buffer[len.*] = 0x11a7 + index % 28;
            len.* += 1;
        }
        return;
    }
    if (lookup(data.Decomposition, &data.decompositions, cp)) |entry| {
        if (compatibility or !entry.compat) {
            for (data.decomposition_data[entry.offset..][0..entry.len]) |child| decompose(child, compatibility, buffer, len);
            return;
        }
    }
    std.debug.assert(len.* < buffer.len);
    buffer[len.*] = cp;
    len.* += 1;
}

pub fn compose(first: u21, second: u21) ?u21 {
    if (first >= 0x1100 and first < 0x1100 + 19 and second >= 0x1161 and second < 0x1161 + 21)
        return 0xac00 + ((first - 0x1100) * 21 + second - 0x1161) * 28;
    if (first >= 0xac00 and first < 0xac00 + 11172 and (first - 0xac00) % 28 == 0 and second > 0x11a7 and second < 0x11a7 + 28)
        return first + second - 0x11a7;
    const key: u42 = (@as(u42, first) << 21) | second;
    var lo: usize = 0;
    var hi = data.compositions.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (data.compositions[mid].key < key) lo = mid + 1 else hi = mid;
    }
    if (lo < data.compositions.len and data.compositions[lo].key == key) return data.compositions[lo].cp;
    return null;
}

pub const Decomposed = struct {
    input: units.Iterator,
    compatibility: bool = false,
    buffer: [18]u21 = undefined,
    len: usize = 0,
    pos: usize = 0,
    pub fn next(self: *Decomposed) ?u21 {
        if (self.pos == self.len) {
            const cp = self.input.next() orelse return null;
            self.len = 0;
            self.pos = 0;
            decompose(cp, self.compatibility, &self.buffer, &self.len);
        }
        const cp = self.buffer[self.pos];
        self.pos += 1;
        return cp;
    }
};

/// Constant-space NFD iterator. A combining run is rescanned to preserve stable
/// order; O(k²) for a run of k marks, avoiding hidden allocation in localeCompare.
pub const CanonicalIterator = struct {
    raw: Decomposed,
    run: ?Decomposed = null,
    run_len: usize = 0,
    emitted: usize = 0,
    last_class: u8 = 0,
    last_index: usize = 0,
    pub fn next(self: *CanonicalIterator) ?u21 {
        if (self.run == null) {
            const begin = self.raw;
            const first = self.raw.next() orelse return null;
            if (combiningClass(first) == 0) return first;
            self.run = begin;
            self.run_len = 1;
            self.emitted = 0;
            while (true) {
                var peek = self.raw;
                const cp = peek.next() orelse break;
                if (combiningClass(cp) == 0) break;
                self.raw = peek;
                self.run_len += 1;
            }
        }
        var scan = self.run.?;
        var selected: ?u21 = null;
        var selected_class: u8 = 255;
        var selected_index: usize = 0;
        for (0..self.run_len) |index| {
            const cp = scan.next().?;
            const class = combiningClass(cp);
            if (self.emitted != 0 and (class < self.last_class or (class == self.last_class and index <= self.last_index))) continue;
            if (selected == null or class < selected_class) {
                selected = cp;
                selected_class = class;
                selected_index = index;
            }
        }
        self.last_class = selected_class;
        self.last_index = selected_index;
        self.emitted += 1;
        if (self.emitted == self.run_len) self.run = null;
        return selected;
    }
};

pub fn compareCanonical(a: []const u8, b: []const u8) isize {
    if (std.mem.eql(u8, a, b)) return 0;
    if (units.isAscii(a) and units.isAscii(b)) return switch (std.mem.order(u8, a, b)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
    var left: CanonicalIterator = .{ .raw = .{ .input = .{ .cursor = .{ .data = a } } } };
    var right: CanonicalIterator = .{ .raw = .{ .input = .{ .cursor = .{ .data = b } } } };
    while (left.next()) |x| {
        const y = right.next() orelse return 1;
        if (x < y) return -1;
        if (x > y) return 1;
    }
    return if (right.next() != null) -1 else 0;
}
