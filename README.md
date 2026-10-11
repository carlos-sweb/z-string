# z-string

**ECMA-262 String operations in Zig 0.17**, with UTF-16 indexing and UTF-8/WTF-8 storage. The goal is functional equivalence: allocators, slices, errors, and callbacks express the operations provided by JavaScript's dynamic mechanisms.

The reference is [ECMA-262: String Objects](https://tc39.es/ecma262/#sec-string-objects). ECMA-262 identifies the standard; the project does not redefine its target as a particular annual edition. ECMA-402 internationalization and Annex B HTML methods are outside the basic profile.

## Verified scope

All 39 operations in the inventory have a functional entry point in Zig. This is **100% operation availability**, not 100% semantic conformance. Six operations that accept RegExp retain restrictions imposed by the dependent engine. See [COMPATIBILIDAD_ECMA262_STRING.md](COMPATIBILIDAD_ECMA262_STRING.md) for the matrix and the distinction between coverage and conformance.

- Character access, search, slicing, padding, and literal splitting by UTF-16 code units, including isolated surrogates.
- Complete Unicode 17.0.0 lowercase and uppercase mappings, including contextual final sigma.
- NFC, NFD, NFKC, and NFKD using complete UCD tables, including Hangul and composition exclusions.
- `isWellFormed`, `toWellFormed`, a code point iterator, and `String.raw` over typed segments.
- Deterministic canonical comparison without an allocator, using a fixed root locale.
- Reusable compiled regex API with flags, exact captures, names, indices, replacement templates, and callbacks.
- Existing API preserved; strict alternatives are additive.

## Installation and testing

Zig 0.17.0 or later is required; `mise.toml` selects 0.17.0. `build.zig.zon` pins `zregex` 0.9.1 to a specific commit and archive hash. Unicode tables are included: building does not require downloading the UCD. Zig downloads the regex dependency if it is not already cached.

```sh
zig build test
zig build test -Doptimize=ReleaseSafe
zig build bench -Doptimize=ReleaseFast
zig build example
```

Consumers add the dependency to their `build.zig.zon` and add `dependency.module("zstring")` to their module imports.

## String API

Each example is an independent, complete Zig 0.17 program. Copy one fenced block into `src/main.zig` in a consumer project that imports the `zstring` module. Allocating examples obtain their allocator from `init.gpa` and release owned results with `defer`. Non-allocating examples explicitly discard `init`. Output comments show the expected result.

The examples cover all **60 public `ZString` functions and aliases**, including ownership helpers and legacy regex wrappers. Additional examples cover the compiled regex API, prepared subjects, captures, callbacks, and cleanup. Functions that return an error union use `try` to propagate errors to `main`; this includes allocation failures.

- [Construction and ownership](#construction-and-ownership)
- [Length, equality, and character access](#length-equality-and-character-access)
- [Search](#search)
- [Slicing, concatenation, padding, and literal replacement](#slicing-concatenation-padding-and-literal-replacement)
- [Splitting and trimming](#splitting-and-trimming)
- [Case conversion, normalization, and string values](#case-conversion-normalization-and-string-values)
- [Legacy regex wrappers](#legacy-regex-wrappers)
- [Compiled regex examples](#compiled-regex-examples)

The `access`, `search`, `transform`, `padding`, `trimming`, `split`, `case`, `utility`, `utf16`, and `regex` modules retain their standalone functions. `ZString` retains all its original methods, including `splitRegex`. The `trimLeft`/`trimRight` aliases remain available.

### Additive alternatives

| API | Contract |
| --- | --- |
| `ZString.fromCharCodeEcma(allocator, []const u16)` | Accepts any UTF-16 code unit, including isolated surrogates. |
| `ZString.fromCodePointEcma(allocator, []const u21)` | Accepts surrogates; rejects values above U+10FFFF. |
| `normalizeStrict(allocator, form)` | Returns `InvalidNormalizationForm` for an unknown form. |
| `toWellFormed(allocator)` | Replaces isolated surrogate halves with U+FFFD and preserves valid pairs. |
| `iterator()` | Borrowed iterator with `next() ?u21`; performs no allocations. |
| `ZString.raw(allocator, segments, substitutions)` | Interleaves raw segments; substitutions are already strings. |
| `replaceLiteral` / `replaceAllLiteral` | Literal UTF-16 search with `$$`, `$&`, prefix, and suffix replacement templates. |

The existing `fromCharCode` and `fromCodePoint` factories **remain strict** about surrogates. `normalize` retains its copy fallback for invalid forms. Numeric arguments are already typed: JavaScript coercion (`ToString`, `ToUint16`, etc.) is the consumer/runtime's responsibility.

### Basic locale profile

`toLocaleLowerCase` and `toLocaleUpperCase` use default Unicode mappings with a fixed root locale. `localeCompare` treats canonically equivalent forms as equal and provides a deterministic total order over normalized code points. Its optional locale/options arguments remain reserved; ECMA-402 and linguistic collation such as ICU are not implemented.

`localeCompare` performs no allocations; a sequence of k combining marks may require O(k²) traversal to maintain stable canonical ordering.

### Construction and ownership

#### `ZString.init`

Borrow an existing string. The input must outlive the wrapper.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("Hello");
    std.debug.print("{s}\n", .{text.data}); // Hello
}
```

#### `ZString.initOwned`

Copy a string into an owned wrapper; release it with deinit.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var text = try z.ZString.initOwned(allocator, "Hello");
    defer text.deinit();
    std.debug.print("{s}\n", .{text.data}); // Hello
}
```

#### `ZString.fromOwned`

Transfer an allocated buffer to a wrapper. The wrapper frees it.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const bytes = try allocator.dupe(u8, "Hello");
    var text = z.ZString.fromOwned(allocator, bytes);
    defer text.deinit();
    std.debug.print("{s}\n", .{text.data}); // Hello
}
```

#### `ZString.fromCharCode`

Build from UTF-16 units. This legacy factory rejects isolated surrogates.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var text = try z.ZString.fromCharCode(allocator, &.{ 65, 66, 67 });
    defer text.deinit();
    std.debug.print("{s}\n", .{text.data}); // ABC
}
```

#### `ZString.fromCodePoint`

Build from code points. This legacy factory rejects surrogates and values above U+10FFFF.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var text = try z.ZString.fromCodePoint(allocator, &.{ 65, 0x1f600 });
    defer text.deinit();
    std.debug.print("{s}\n", .{text.data}); // A😀
}
```

#### `ZString.fromCharCodeEcma`

Build from any UTF-16 units, including isolated surrogates.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var text = try z.ZString.fromCharCodeEcma(allocator, &.{ 65, 0xd800 });
    defer text.deinit();
    std.debug.print("Length: {d}; last unit: {X}\n", .{ text.lengthConst(), text.charCodeAt(1).? });
    // Length: 2; last unit: D800
}
```

#### `ZString.fromCodePointEcma`

Build from code points, accepting surrogates; values above U+10FFFF produce CodepointTooLarge.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var text = try z.ZString.fromCodePointEcma(allocator, &.{ 65, 0x1f600 });
    defer text.deinit();
    std.debug.print("{s}\n", .{text.data}); // A😀
}
```

#### `ZString.raw`

Interleave raw segments and string substitutions without interpreting escapes.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const result = try z.ZString.raw(allocator, &.{ "Hello ", "!" }, &.{"Zig"});
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // Hello Zig!
}
```

#### `ZString.clone`

Create an independent owned copy of a wrapper.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const original = z.ZString.init("Hello");
    var copy = try original.clone(allocator);
    defer copy.deinit();
    std.debug.print("{s}\n", .{copy.data}); // Hello
}
```

#### `ZString.deinit`

Release an owned wrapper. Calling deinit on a borrowed wrapper is safe.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var text = try z.ZString.initOwned(allocator, "Hello");
    text.deinit();
    std.debug.print("Owned after deinit: {}\n", .{text.isOwned()}); // false
}
```

### Length, equality, and character access

#### `ZString.length`

Return and cache the UTF-16 length.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    var text = z.ZString.init("A😀B");
    std.debug.print("{d}\n", .{text.length()}); // 4
}
```

#### `ZString.lengthConst`

Return the UTF-16 length without caching.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("A😀B");
    std.debug.print("{d}\n", .{text.lengthConst()}); // 4
}
```

#### `ZString.byteLength`

Return the storage size in bytes, rather than UTF-16 units.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("A😀B");
    std.debug.print("{d}\n", .{text.byteLength()}); // 6
}
```

#### `ZString.isEmpty`

Check whether the string is empty.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("");
    std.debug.print("{}\n", .{text.isEmpty()}); // true
}
```

#### `ZString.isOwned`

Check whether the wrapper owns its buffer.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var text = try z.ZString.initOwned(allocator, "Hello");
    defer text.deinit();
    std.debug.print("{}\n", .{text.isOwned()}); // true
}
```

#### `ZString.eql`

Compare two wrappers by their UTF-16 contents.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const left = z.ZString.init("Hello");
    const right = z.ZString.init("Hello");
    std.debug.print("{}\n", .{left.eql(right)}); // true
}
```

#### `ZString.eqlSlice`

Compare a wrapper with a UTF-8/WTF-8 slice.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("Hello");
    std.debug.print("{}\n", .{text.eqlSlice("Hello")}); // true
}
```

#### `ZString.charAt`

Return one UTF-16 unit as an owned string; out-of-range indices return an empty string.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("Hello");
    const result = try text.charAt(allocator, 1);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // e
}
```

#### `ZString.at`

Access a UTF-16 unit using a relative index; out-of-range indices return null.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("Hello");
    if (try text.at(allocator, -1)) |result| {
        defer allocator.free(result);
        std.debug.print("{s}\n", .{result}); // o
    }
}
```

#### `ZString.charCodeAt`

Return a numeric UTF-16 code unit, or null outside the string.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("😀");
    if (text.charCodeAt(0)) |unit| {
        std.debug.print("{X}\n", .{unit}); // D83D: high surrogate
    }
}
```

#### `ZString.codePointAt`

Decode the code point starting at a UTF-16 index, or return null outside the string.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("😀");
    if (text.codePointAt(0)) |point| {
        std.debug.print("U+{X}\n", .{point}); // U+1F600
    }
}
```

#### `ZString.iterator`

Iterate over code points with next(), without allocating. Isolated surrogates are also yielded.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("A😀B");
    var iterator = text.iterator();
    while (iterator.next()) |point| {
        std.debug.print("U+{X}\n", .{point});
    }
    // U+41, U+1F600, U+42 on separate lines.
}
```

#### `ZString.isWellFormed`

Check whether all UTF-16 surrogate units are paired.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var text = try z.ZString.fromCharCodeEcma(allocator, &.{0xd800});
    defer text.deinit();
    std.debug.print("{}\n", .{text.isWellFormed()}); // false
}
```

#### `ZString.toWellFormed`

Replace isolated surrogates with U+FFFD in an owned result.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var text = try z.ZString.fromCharCodeEcma(allocator, &.{0xd800});
    defer text.deinit();
    const result = try text.toWellFormed(allocator);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // � (U+FFFD)
}
```

### Search

#### `ZString.includes`

Check whether a literal string occurs at or after the optional UTF-16 position.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("Hello world");
    std.debug.print("{}\n", .{text.includes("world", null)}); // true
}
```

#### `ZString.indexOf`

Find the first literal occurrence; return -1 if absent.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("Hello world");
    std.debug.print("{d}\n", .{text.indexOf("o", null)}); // 4
}
```

#### `ZString.lastIndexOf`

Find the last literal occurrence at or before the optional position.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("Hello world");
    std.debug.print("{d}\n", .{text.lastIndexOf("o", null)}); // 7
}
```

#### `ZString.startsWith`

Check a literal prefix at the optional UTF-16 position.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("Hello world");
    std.debug.print("{}\n", .{text.startsWith("Hello", null)}); // true
}
```

#### `ZString.endsWith`

Check a literal suffix at the optional UTF-16 end position.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("Hello world");
    std.debug.print("{}\n", .{text.endsWith("world", null)}); // true
}
```

### Slicing, concatenation, padding, and literal replacement

#### `ZString.slice`

Extract a UTF-16 interval; negative indices count from the end.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("Hello");
    const result = try text.slice(allocator, 1, 4);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // ell
}
```

#### `ZString.substring`

Extract an interval, clamping negative indices and swapping reversed endpoints.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("Hello");
    const result = try text.substring(allocator, 4, 1);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // ell
}
```

#### `ZString.concat`

Concatenate strings, including surrogate pairs formed at joins.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("Hello");
    const result = try text.concat(allocator, &.{ " ", "world" });
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // Hello world
}
```

#### `ZString.repeat`

Repeat a string. Negative counts produce InvalidCount.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("ab");
    const result = try text.repeat(allocator, 3);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // ababab
}
```

#### `ZString.padStart`

Pad the start to a target UTF-16 length.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("7");
    const result = try text.padStart(allocator, 3, "0");
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // 007
}
```

#### `ZString.padEnd`

Pad the end to a target UTF-16 length.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("7");
    const result = try text.padEnd(allocator, 3, "0");
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // 700
}
```

#### `ZString.replaceLiteral`

Replace the first literal match, expanding substitution templates.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("one one");
    const result = try text.replaceLiteral(allocator, "one", "[$&]");
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // [one] one
}
```

#### `ZString.replaceAllLiteral`

Replace all literal matches, expanding substitution templates.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("one one");
    const result = try text.replaceAllLiteral(allocator, "one", "[$&]");
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // [one] [one]
}
```

### Splitting and trimming

#### `ZString.split`

Split using a literal separator and free both the array and its strings.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("a,b,c");
    const pieces = try text.split(allocator, ",", null);
    defer z.ZString.freeSplitResult(allocator, pieces);
    for (pieces) |piece| std.debug.print("{s}\n", .{piece});
    // a, b, c on separate lines.
}
```

#### `ZString.freeSplitResult`

Release every owned piece and the array returned by split or splitRegex.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("a,b,c");
    const pieces = try text.split(allocator, ",", null);
    defer z.ZString.freeSplitResult(allocator, pieces);
    for (pieces) |piece| std.debug.print("{s}\n", .{piece});
    // a, b, c on separate lines.
}
```

#### `ZString.trim`

Remove ECMAScript whitespace from both ends.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("  Hello  ");
    const result = try text.trim(allocator);
    defer allocator.free(result);
    std.debug.print("[{s}]\n", .{result}); // [Hello]
}
```

#### `ZString.trimStart`

Remove whitespace from the beginning.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("  Hello  ");
    const result = try text.trimStart(allocator);
    defer allocator.free(result);
    std.debug.print("[{s}]\n", .{result}); // [Hello  ]
}
```

#### `ZString.trimEnd`

Remove whitespace from the end.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("  Hello  ");
    const result = try text.trimEnd(allocator);
    defer allocator.free(result);
    std.debug.print("[{s}]\n", .{result}); // [  Hello]
}
```

#### `ZString.trimLeft`

Use the legacy alias for trimStart.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("  Hello  ");
    const result = try text.trimLeft(allocator);
    defer allocator.free(result);
    std.debug.print("[{s}]\n", .{result}); // [Hello  ]
}
```

#### `ZString.trimRight`

Use the legacy alias for trimEnd.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("  Hello  ");
    const result = try text.trimRight(allocator);
    defer allocator.free(result);
    std.debug.print("[{s}]\n", .{result}); // [  Hello]
}
```

### Case conversion, normalization, and string values

#### `ZString.toLowerCase`

Apply complete Unicode default lowercase mappings.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("CAFÉ");
    const result = try text.toLowerCase(allocator);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // café
}
```

#### `ZString.toUpperCase`

Apply complete Unicode uppercase mappings, including expansions.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("Straße");
    const result = try text.toUpperCase(allocator);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // STRASSE
}
```

#### `ZString.toLocaleLowerCase`

Use the fixed root locale; locale-specific ECMA-402 mappings are not implemented.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("CAFÉ");
    const result = try text.toLocaleLowerCase(allocator, null);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // café
}
```

#### `ZString.toLocaleUpperCase`

Use the fixed root locale; the optional locale argument is reserved.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("Straße");
    const result = try text.toLocaleUpperCase(allocator, null);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // STRASSE
}
```

#### `ZString.normalize`

Normalize using NFC, NFD, NFKC, or NFKD; invalid forms retain the legacy copy fallback.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("e\u{0301}");
    const result = try text.normalize(allocator, "NFC");
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // é
}
```

#### `ZString.normalizeStrict`

Normalize with explicit InvalidNormalizationForm errors for unknown forms.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("e\u{0301}");
    const result = try text.normalizeStrict(allocator, "NFC");
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // é
}
```

#### `ZString.toStringAlloc`

Return an owned copy of the string value.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("Hello");
    const result = try text.toStringAlloc(allocator);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // Hello
}
```

#### `ZString.valueOfAlloc`

Return an owned copy of the wrapped value.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("Hello");
    const result = try text.valueOfAlloc(allocator);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // Hello
}
```

#### `ZString.localeCompare`

Compare canonically equivalent strings using the fixed root profile. Locale and options arguments are reserved.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const text = z.ZString.init("é");
    const order = text.localeCompare("e\u{0301}", null, null);
    std.debug.print("{d}\n", .{order}); // 0
}
```

### Legacy regex wrappers

#### `ZString.searchRegex`

Find a regex match and return its UTF-16 index. Legacy syntax/execution failures can return -1.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("abc123");
    const index = try text.searchRegex(allocator, "[0-9]+");
    std.debug.print("{d}\n", .{index}); // 3
}
```

#### `ZString.matchRegex`

Return the first legacy match, or null. Free an owned result with MatchArray.deinit.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("abc123");
    if (try text.matchRegex(allocator, "[0-9]+")) |match| {
        defer match.deinit();
        std.debug.print("{s}\n", .{match.match}); // 123
    }
}
```

#### `ZString.matchAllRegex`

Collect legacy matches and free each match together with the result array.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("a1 b22");
    const matches = try text.matchAllRegex(allocator, "[0-9]+");
    defer z.ZString.freeMatchAllResult(allocator, matches);
    for (matches) |match| std.debug.print("{s}\n", .{match.match});
    // 1, 22 on separate lines.
}
```

#### `ZString.freeMatchAllResult`

Release the array and all MatchArray values returned by matchAllRegex.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("a1 b22");
    const matches = try text.matchAllRegex(allocator, "[0-9]+");
    defer z.ZString.freeMatchAllResult(allocator, matches);
    for (matches) |match| std.debug.print("{s}\n", .{match.match});
    // 1, 22 on separate lines.
}
```

#### `ZString.replaceRegex`

Replace regex matches using the legacy API. Replacement text is inserted literally, without template expansion.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("a1 b22");
    const result = try text.replaceRegex(allocator, "[0-9]+", "#");
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // a# b22
}
```

#### `ZString.replaceAllRegex`

Replace regex matches using the legacy API. Replacement text is inserted literally, without template expansion.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("a1 b22");
    const result = try text.replaceAllRegex(allocator, "[0-9]+", "#");
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // a# b#
}
```

#### `ZString.splitRegex`

Split using a regex separator. Absent captures become empty strings in this legacy wrapper.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const text = z.ZString.init("a1b22c");
    const pieces = try text.splitRegex(allocator, "[0-9]+", null);
    defer z.ZString.freeSplitResult(allocator, pieces);
    for (pieces) |piece| std.debug.print("{s}\n", .{piece});
    // a, b, c on separate lines.
}
```

## Strict, reusable regex API

### Compiled regex examples

#### `CompiledRegex.compile`

Compile a reusable pattern. Invalid syntax, unsupported features, duplicate flags, or invalid flag combinations produce errors.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "(?<word>[a-z]+)", "gdi");
    defer re.deinit();
    std.debug.print("{d}\n", .{try re.search("123 One")}); // 4
}
```

#### `CompiledRegex.deinit`

Release the compiled pattern and its scratch storage. Do not copy an owning CompiledRegex.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "[a-z]+", "");
    re.deinit();
    std.debug.print("Regex released\n", .{});
}
```

#### `CompiledRegex.setLimits`

Configure backtracking budgets. The linear VM does not use these limits.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "(?<word>[a-z]+)", "gdi");
    defer re.deinit();
    re.setLimits(.{ .max_steps = 100_000, .max_backtrack_stack_bytes = 1024 * 1024 });
    std.debug.print("{d}\n", .{try re.search("One")}); // 0
}
```

#### `CompiledRegex.search`

Return the first match index in UTF-16 units, or -1.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "(?<word>[a-z]+)", "gdi");
    defer re.deinit();
    std.debug.print("{d}\n", .{try re.search("123 One")}); // 4
}
```

#### `CompiledRegex.match`

Return one detailed match starting at a UTF-16 position. This API returns one match even when g is set.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "(?<word>[a-z]+)", "gdi");
    defer re.deinit();
    if (try re.match("One two", 0)) |match| {
        defer match.deinit();
        std.debug.print("{s}\n", .{match.match}); // One
    }
}
```

#### `CompiledRegex.matchAll`

Collect detailed matches. The g flag is required; otherwise GlobalFlagRequired is returned.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "(?<word>[a-z]+)", "gdi");
    defer re.deinit();
    const matches = try re.matchAll("One two");
    defer z.compiled_regex.freeMatches(allocator, matches);
    for (matches) |match| std.debug.print("{s}\n", .{match.match});
    // One, two on separate lines.
}
```

#### `CompiledRegex.replace`

Expand replacement templates; g selects all matches instead of only the first.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "(?<word>[a-z]+)", "gdi");
    defer re.deinit();
    const result = try re.replace("One two", "[$<word>]");
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // [One] [two]
}
```

#### `CompiledRegex.replaceAll`

Replace every match with template expansion. The g flag is required.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "(?<word>[a-z]+)", "gdi");
    defer re.deinit();
    const result = try re.replaceAll("One two", "[$<word>]");
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // [One] [two]
}
```

#### `CompiledRegex.replaceWith`

Generate replacement text with a callback. The callback must return bytes allocated by the supplied allocator.

```zig
const std = @import("std");
const z = @import("zstring");

fn uppercase(_: ?*anyopaque, match: z.DetailedMatch, allocator: std.mem.Allocator) ![]u8 {
    return z.ZString.init(match.match).toUpperCase(allocator);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "(?<word>[a-z]+)", "gdi");
    defer re.deinit();
    const result = try re.replaceWith("One two", null, uppercase);
    defer allocator.free(result);
    std.debug.print("{s}\n", .{result}); // ONE TWO
}
```

#### `CompiledRegex.split`

Split with regex captures. Nonparticipating captures are null; free with compiled_regex.freeSplit.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "[0-9]+", "");
    defer re.deinit();
    const pieces = try re.split("a1b22c", null);
    defer z.compiled_regex.freeSplit(allocator, pieces);
    for (pieces) |piece| {
        if (piece) |text| std.debug.print("{s}\n", .{text});
    }
    // a, b, c on separate lines.
}
```

#### `CompiledRegex.execAt`

Execute on a prepared subject at a UTF-16 position. Returned slots are borrowed and overwritten by the next execution.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "(?<word>[a-z]+)", "gdi");
    defer re.deinit();
    const subject = try z.PreparedSubject.init(allocator, "One two");
    defer subject.deinit();
    if (try re.execAt(subject, 4)) |view| {
        std.debug.print("{d}..{d}\n", .{ view.index, view.end }); // 4..7
    }
}
```

#### `PreparedSubject.init / deinit`

Prepare and release owned UTF-16 storage while borrowing the original input. Invalid non-WTF-8 input produces InvalidUtf8.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const subject = try z.PreparedSubject.init(allocator, "A😀B");
    defer subject.deinit();
    std.debug.print("{d}\n", .{subject.data.len}); // 4 UTF-16 units
}
```

#### `DetailedMatch.named / deinit`

Read a named capture and release the owned match. The returned capture slice is borrowed from the match.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "(?<word>[a-z]+)", "gdi");
    defer re.deinit();
    if (try re.match("One two", 0)) |match| {
        defer match.deinit();
        if (match.named("word")) |word| std.debug.print("{s}\n", .{word}); // One
    }
}
```

#### `compiled_regex.freeMatches`

Free all detailed matches and their result array.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, "(?<word>[a-z]+)", "gdi");
    defer re.deinit();
    const matches = try re.matchAll("One two");
    defer z.compiled_regex.freeMatches(allocator, matches);
    std.debug.print("{d}\n", .{matches.len}); // 2
}
```

#### `compiled_regex.freeSplit`

Free every present split piece and its result array.

```zig
const std = @import("std");
const z = @import("zstring");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var re = try z.CompiledRegex.compile(allocator, ",", "");
    defer re.deinit();
    const pieces = try re.split("a,b", null);
    defer z.compiled_regex.freeSplit(allocator, pieces);
    std.debug.print("{d}\n", .{pieces.len}); // 2
}
```

- Flags: `d`, `g`, `i`, `m`, `s`, `u`, `v`, `y`; duplicates and invalid combinations produce errors.
- `search`, `match(input, start)`, `matchAll`, `replace`, `replaceAll`, `replaceWith`, and `split` propagate syntax, memory, and execution errors.
- `DetailedMatch` contains the match, exact captures, names, start/end indices, and each capture's indices. `indices[0]` refers to the full match. Indices are exposed even without `d`.
- `matchAll` and `replaceAll` require `g`. Empty matches advance by one UTF-16 code unit, or one code point under `u`/`v`, and include the final match where appropriate.
- `split` returns `[]?[]u8`: a nonparticipating capture is `null`. Free the result with `compiled_regex.freeSplit`.
- Regex templates additionally support `$1`…`$99` and `$<name>`. `replaceWith` accepts a callback and optional context; the callback receives a borrowed result and returns owned bytes allocated with the supplied allocator.
- `setLimits` configures backtracking limits; the linear VM does not use those limits.

A `CompiledRegex` owns its pattern, slots, and scratch storage; do not copy it or share it for concurrent execution. `PreparedSubject` owns its UTF-16 buffer and borrows the input. The input must outlive the subject and any `DetailedMatch` that references it. `MatchView.slots` is overwritten by the next execution. The tested `execAt` routes reuse memory after warmup; APIs that prepare strings or return owned results do allocate memory.

The existing `searchRegex`/`matchRegex`/`matchAllRegex`/`replaceRegex`/`replaceAllRegex` wrappers retain their historical fallbacks. Legacy replacements insert replacement text without expanding templates; `MatchArray.groups` retains its 15 slots. `splitRegex` retains `[][]u8`, corrects empty-match advancement and capture handling, and represents an absent capture as `""`. Use the compiled API to distinguish an absent capture from an empty one.

### Remaining restrictions

The pinned `zregex` engine rejects certain valid `iv` combinations, local modifiers, and complex lookbehind patterns with `UnsupportedFeature`. Full RegExp conformance is not claimed. Legacy wrappers also retain behaviors of the backend's byte facade and their error fallbacks; use `CompiledRegex` for UTF-16 semantics and explicit errors.

Malformed UTF-8 that is not WTF-8 is outside the ECMA-262 string domain. The historical API retains its byte fallbacks; `PreparedSubject` rejects such input. `toWellFormed` repairs isolated surrogates but preserves these historical malformed bytes: it is not a validator for arbitrary binary files.

## Validation and documentation

Latest local verification with **Zig 0.17.0 and zregex 0.9.1**: **417/417 tests** pass in Debug and ReleaseSafe; all six repository examples and tests run from the packaged contents also pass. All **75 complete programs in this README** also compile and run with Zig 0.17.0.

The detailed reports linked below are in Spanish.

- [Compatibility matrix and scope percentages](COMPATIBILIDAD_ECMA262_STRING.md).
- [Unicode data and regeneration](UNICODE.md).
- 55 assertions adapted from eight official Test262 sources pinned by commit, with originals, hashes, and license preserved. These do not execute portions that require a JavaScript object runtime.
- 9,216 deterministic differential cases against Node and the official Unicode normalization corpus: 20,034 records, four forms, and five inputs per record.
- Simple and full case mappings tested against UnicodeData/SpecialCasing; allocation failures and frozen public API signatures are also checked.

These datasets do not constitute a complete Test262 run or certify universal conformance. Tests run without Node or Python; those tools are only needed to regenerate the artifacts.

## Licenses

The code uses [MIT](LICENSE). Unicode tables and corpora are covered by [Unicode License v3](src/unicode/LICENSE.txt); their sources and hashes are recorded in `src/unicode/SOURCES.txt`.

The selected Test262 sources and adaptations retain [Ecma International's BSD license](tests/spec/data/test262/LICENSE).
