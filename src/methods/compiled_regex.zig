//! Strict, reusable regex API. Legacy wrappers keep their historical fallbacks.
const std = @import("std");
const backend = @import("zregex");
const units = @import("../core/units.zig");
const utf16 = @import("../core/utf16.zig");
const search = @import("search.zig");
const Allocator = std.mem.Allocator;
pub const ExecLimits = backend.ExecLimits;

pub const NamedCapture = struct { name: []const u8, index: usize };
pub const DetailedMatch = struct {
    match: []u8,
    captures: []?[]u8,
    index: usize,
    end: usize,
    /// Borrowed original input; must outlive this result.
    input: []const u8,
    indices: []?[2]usize,
    named_groups: []NamedCapture,
    allocator: Allocator,
    pub fn deinit(self: DetailedMatch) void {
        self.allocator.free(self.match);
        for (self.captures) |capture| if (capture) |text| self.allocator.free(text);
        self.allocator.free(self.captures);
        self.allocator.free(self.indices);
        for (self.named_groups) |group| self.allocator.free(group.name);
        self.allocator.free(self.named_groups);
    }
    pub fn named(self: DetailedMatch, name: []const u8) ?[]const u8 {
        for (self.named_groups) |group| {
            if (std.mem.eql(u8, name, group.name)) if (self.captures[group.index - 1]) |text| return text;
        }
        return null;
    }
};

/// Owned UTF-16 preparation, reused for repeated executions. `input` is borrowed.
pub const PreparedSubject = struct {
    input: []const u8,
    data: []u16,
    allocator: Allocator,
    pub fn init(allocator: Allocator, input: []const u8) !PreparedSubject {
        const data = try allocator.alloc(u16, utf16.lengthUtf16(input));
        errdefer allocator.free(data);
        var cursor: units.Cursor = .{ .data = input };
        for (data) |*cp| {
            const unit = cursor.next().?;
            if (!unit.valid) return error.InvalidUtf8;
            cp.* = unit.value;
        }
        return .{ .input = input, .data = data, .allocator = allocator };
    }
    pub fn deinit(self: PreparedSubject) void {
        self.allocator.free(self.data);
    }
};

pub const MatchView = struct {
    index: usize,
    end: usize,
    /// Borrowed slots in UTF-16 units; overwritten by the next execution.
    slots: []const ?usize,
};

/// One compiled regex and scratch per thread. Do not copy an owning instance.
pub const CompiledRegex = struct {
    re: backend.Regex,
    scratch: backend.Scratch,
    slots: backend.MatchSlots,
    pattern: []u8,
    allocator: Allocator,
    global: bool,

    /// Flags: d,g,i,m,s,u,v,y. Syntax and execution errors are propagated.
    pub fn compile(allocator: Allocator, pattern: []const u8, flags: []const u8) !CompiledRegex {
        if (!std.unicode.wtf8ValidateSlice(pattern)) return error.InvalidUtf8;
        var options: backend.CompileOptions = .{};
        var global = false;
        var seen: [128]bool = @splat(false);
        for (flags) |flag| {
            if (flag >= seen.len or seen[flag]) return error.InvalidFlags;
            seen[flag] = true;
            switch (flag) {
                'd' => {}, // Indices are always exposed by this typed API.
                'g' => global = true,
                'i' => options.case_insensitive = true,
                'm' => options.multiline = true,
                's' => options.dot_all = true,
                'u' => options.unicode = true,
                'v' => options.v = true,
                'y' => options.sticky = true,
                else => return error.InvalidFlags,
            }
        }
        const owned = try allocator.dupe(u8, pattern);
        errdefer allocator.free(owned);
        var re = try backend.Regex.compileWithOptions(allocator, owned, options);
        errdefer re.deinit();
        const slots = try allocator.alloc(?usize, re.slotCount());
        return .{ .re = re, .scratch = backend.Scratch.init(allocator), .slots = .{ .slots = slots }, .pattern = owned, .allocator = allocator, .global = global };
    }
    pub fn deinit(self: *CompiledRegex) void {
        self.scratch.deinit();
        self.re.deinit();
        self.allocator.free(self.slots.slots);
        self.allocator.free(self.pattern);
        self.* = undefined;
    }

    /// Limits apply to the backtracking route; the linear VM ignores them.
    pub fn setLimits(self: *CompiledRegex, limits: ExecLimits) void {
        self.re.limits = limits;
    }

    /// Reuses scratch; allocation-free after warmup on the chosen backend route.
    pub fn execAt(self: *CompiledRegex, subject: PreparedSubject, start: usize) !?MatchView {
        if (start > subject.data.len) return null;
        if (!try self.re.execAt(.{ .utf16 = subject.data }, start, &self.scratch, &self.slots, self.re.limits)) return null;
        return .{ .index = self.slots.slots[0].?, .end = self.slots.slots[1].?, .slots = self.slots.slots };
    }

    pub fn search(self: *CompiledRegex, input: []const u8) !isize {
        const subject = try PreparedSubject.init(self.allocator, input);
        defer subject.deinit();
        return if (try self.execAt(subject, 0)) |m| @intCast(m.index) else -1;
    }

    /// First match with exact capture count, names and UTF-16 indices.
    pub fn match(self: *CompiledRegex, input: []const u8, start: usize) !?DetailedMatch {
        const subject = try PreparedSubject.init(self.allocator, input);
        defer subject.deinit();
        return if (try self.execAt(subject, start)) |m| try self.copyMatch(subject, m) else null;
    }

    pub fn matchAll(self: *CompiledRegex, input: []const u8) ![]DetailedMatch {
        if (!self.global) return error.GlobalFlagRequired;
        const subject = try PreparedSubject.init(self.allocator, input);
        defer subject.deinit();
        var out: std.ArrayList(DetailedMatch) = .empty;
        defer out.deinit(self.allocator);
        errdefer for (out.items) |m| m.deinit();
        var position: usize = 0;
        while (try self.execAt(subject, position)) |m| {
            const owned = try self.copyMatch(subject, m);
            errdefer owned.deinit();
            try out.append(self.allocator, owned);
            if (m.end == m.index) {
                if (m.end == subject.data.len) break;
                position = self.re.advanceIndex(.{ .utf16 = subject.data }, m.end);
            } else position = m.end;
        }
        return out.toOwnedSlice(self.allocator);
    }

    fn copyMatch(self: *CompiledRegex, subject: PreparedSubject, view: MatchView) !DetailedMatch {
        const match_text = try units.range(self.allocator, subject.input, view.index, view.end);
        errdefer self.allocator.free(match_text);
        const captures = try self.allocator.alloc(?[]u8, self.re.groupCount());
        @memset(captures, null);
        errdefer {
            for (captures) |capture| if (capture) |text| self.allocator.free(text);
            self.allocator.free(captures);
        }
        const indices = try self.allocator.alloc(?[2]usize, captures.len + 1);
        errdefer self.allocator.free(indices);
        for (indices, 0..) |*pair, i| {
            pair.* = if (view.slots[2 * i]) |a| .{ a, view.slots[2 * i + 1].? } else null;
            if (i != 0) if (pair.*) |range| {
                captures[i - 1] = try units.range(self.allocator, subject.input, range[0], range[1]);
            };
        }
        const names = try self.allocator.alloc(NamedCapture, self.re.compiled.named_groups.len);
        var copied: usize = 0;
        errdefer {
            for (names[0..copied]) |group| self.allocator.free(group.name);
            self.allocator.free(names);
        }
        for (names, self.re.compiled.named_groups) |*target, group| {
            target.* = .{ .name = try self.allocator.dupe(u8, group.name), .index = group.index };
            copied += 1;
        }
        return .{ .match = match_text, .captures = captures, .index = view.index, .end = view.end, .input = subject.input, .indices = indices, .named_groups = names, .allocator = self.allocator };
    }

    /// ECMA-262 substitution templates. `g` controls first/all replacement.
    pub fn replace(self: *CompiledRegex, input: []const u8, replacement: []const u8) ![]u8 {
        return self.replaceImpl(input, replacement, null, null);
    }
    pub fn replaceAll(self: *CompiledRegex, input: []const u8, replacement: []const u8) ![]u8 {
        if (!self.global) return error.GlobalFlagRequired;
        return self.replace(input, replacement);
    }
    /// Callback sees a borrowed result and returns owned bytes from `allocator`.
    pub const Replacer = *const fn (context: ?*anyopaque, match_result: DetailedMatch, allocator: Allocator) anyerror![]u8;
    pub fn replaceWith(self: *CompiledRegex, input: []const u8, context: ?*anyopaque, callback: Replacer) ![]u8 {
        return self.replaceImpl(input, "", context, callback);
    }
    fn replaceImpl(self: *CompiledRegex, input: []const u8, replacement: []const u8, context: ?*anyopaque, callback: ?Replacer) ![]u8 {
        const subject = try PreparedSubject.init(self.allocator, input);
        defer subject.deinit();
        var out: units.Builder = .{ .allocator = self.allocator };
        defer out.deinit();
        var position: usize = 0;
        var previous: usize = 0;
        while (try self.execAt(subject, position)) |view| {
            const found = try self.copyMatch(subject, view);
            defer found.deinit();
            const prefix = try units.range(self.allocator, input, previous, view.index);
            defer self.allocator.free(prefix);
            try out.appendString(prefix);
            if (callback) |function| {
                const replaced = try function(context, found, self.allocator);
                defer self.allocator.free(replaced);
                try out.appendString(replaced);
            } else try expand(&out, replacement, found);
            previous = view.end;
            if (!self.global) break;
            if (view.end == view.index) {
                if (view.end == subject.data.len) break;
                position = self.re.advanceIndex(.{ .utf16 = subject.data }, view.end);
            } else position = view.end;
        }
        const suffix = try units.range(self.allocator, input, previous, subject.data.len);
        defer self.allocator.free(suffix);
        try out.appendString(suffix);
        return out.finish();
    }

    /// Nullable captures preserve non-participating groups. Free with freeSplit().
    pub fn split(self: *CompiledRegex, input: []const u8, limit: ?usize) ![]?[]u8 {
        const allocator = self.allocator;
        var out: std.ArrayList(?[]u8) = .empty;
        defer out.deinit(allocator);
        errdefer for (out.items) |piece| if (piece) |text| allocator.free(text);
        const max = limit orelse std.math.maxInt(u32);
        if (max == 0) return out.toOwnedSlice(allocator);
        const subject = try PreparedSubject.init(allocator, input);
        defer subject.deinit();
        const sticky = self.re.sticky;
        self.re.sticky = true;
        defer self.re.sticky = sticky;
        if (subject.data.len == 0) {
            if (try self.execAt(subject, 0) != null) return out.toOwnedSlice(allocator);
            try appendPiece(&out, allocator, try allocator.dupe(u8, input));
            return out.toOwnedSlice(allocator);
        }
        var previous: usize = 0;
        var position: usize = 0;
        while (position < subject.data.len) {
            if (try self.execAt(subject, position)) |view| {
                if (view.end == previous) {
                    position = self.re.advanceIndex(.{ .utf16 = subject.data }, position);
                    continue;
                }
                try appendPiece(&out, allocator, try units.range(allocator, input, previous, position));
                if (out.items.len >= max) return out.toOwnedSlice(allocator);
                previous = view.end;
                for (1..self.re.groupCount() + 1) |i| {
                    const text = if (view.slots[2 * i]) |start| try units.range(allocator, input, start, view.slots[2 * i + 1].?) else null;
                    try appendPiece(&out, allocator, text);
                    if (out.items.len >= max) return out.toOwnedSlice(allocator);
                }
                position = previous;
            } else position = self.re.advanceIndex(.{ .utf16 = subject.data }, position);
        }
        try appendPiece(&out, allocator, try units.range(allocator, input, previous, subject.data.len));
        return out.toOwnedSlice(allocator);
    }
};

fn appendPiece(out: *std.ArrayList(?[]u8), allocator: Allocator, text: ?[]u8) !void {
    errdefer if (text) |owned| allocator.free(owned);
    try out.append(allocator, text);
}
pub fn freeSplit(allocator: Allocator, pieces: []?[]u8) void {
    for (pieces) |piece| if (piece) |text| allocator.free(text);
    allocator.free(pieces);
}
pub fn freeMatches(allocator: Allocator, matches: []DetailedMatch) void {
    for (matches) |m| m.deinit();
    allocator.free(matches);
}

fn expand(out: *units.Builder, template: []const u8, found: DetailedMatch) !void {
    var i: usize = 0;
    var literal: usize = 0;
    while (i < template.len) {
        if (template[i] != '$' or i + 1 >= template.len) {
            i += 1;
            continue;
        }
        var value: ?[]const u8 = null;
        var owned: ?[]u8 = null;
        defer if (owned) |text| out.allocator.free(text);
        var consumed: usize = 2;
        switch (template[i + 1]) {
            '$' => value = "$",
            '&' => value = found.match,
            '`' => {
                owned = try units.range(out.allocator, found.input, 0, found.index);
                value = owned;
            },
            '\'' => {
                owned = try units.range(out.allocator, found.input, found.end, utf16.lengthUtf16(found.input));
                value = owned;
            },
            '0'...'9' => {
                var number: usize = template[i + 1] - '0';
                if (i + 2 < template.len and std.ascii.isDigit(template[i + 2])) {
                    const two = number * 10 + template[i + 2] - '0';
                    if (two > 0 and two <= found.captures.len) {
                        number = two;
                        consumed = 3;
                    }
                }
                if (number > 0 and number <= found.captures.len) value = found.captures[number - 1] orelse "";
            },
            '<' => {
                if (found.named_groups.len != 0) if (std.mem.indexOfScalarPos(u8, template, i + 2, '>')) |end| {
                    value = found.named(template[i + 2 .. end]) orelse "";
                    consumed = end - i + 1;
                };
            },
            else => {},
        }
        if (value) |text| {
            try out.appendString(template[literal..i]);
            try out.appendString(text);
            i += consumed;
            literal = i;
        } else i += 1;
    }
    try out.appendString(template[literal..]);
}

pub fn replaceLiteral(allocator: Allocator, input: []const u8, needle: []const u8, replacement: []const u8) ![]u8 {
    return replaceLiteralImpl(allocator, input, needle, replacement, false);
}
pub fn replaceAllLiteral(allocator: Allocator, input: []const u8, needle: []const u8, replacement: []const u8) ![]u8 {
    return replaceLiteralImpl(allocator, input, needle, replacement, true);
}
fn replaceLiteralImpl(allocator: Allocator, input: []const u8, needle: []const u8, replacement: []const u8, all: bool) ![]u8 {
    var out: units.Builder = .{ .allocator = allocator };
    defer out.deinit();
    const len = utf16.lengthUtf16(input);
    const needle_len = utf16.lengthUtf16(needle);
    var previous: usize = 0;
    var position: usize = 0;
    while (position <= len) {
        const index = search.indexOf(input, needle, @intCast(position));
        if (index < 0) break;
        const start: usize = @intCast(index);
        const prefix = try units.range(allocator, input, previous, start);
        defer allocator.free(prefix);
        try out.appendString(prefix);
        var no_captures: [0]?[]u8 = .{};
        var no_indices: [0]?[2]usize = .{};
        var no_names: [0]NamedCapture = .{};
        const matched = try units.range(allocator, input, start, start + needle_len);
        defer allocator.free(matched);
        try expand(&out, replacement, .{ .match = matched, .captures = &no_captures, .indices = &no_indices, .named_groups = &no_names, .index = start, .end = start + needle_len, .input = input, .allocator = allocator });
        previous = start + needle_len;
        if (!all or previous == len and needle_len == 0) break;
        position = previous + @intFromBool(needle_len == 0);
    }
    const suffix = try units.range(allocator, input, previous, len);
    defer allocator.free(suffix);
    try out.appendString(suffix);
    return out.finish();
}
