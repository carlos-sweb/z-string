# z-string

**ECMAScript String API implementation in Zig**

[![Zig Version](https://img.shields.io/badge/zig-0.16-orange.svg)](https://ziglang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-active-green.svg)](#-project-status)

A Zig library implementing the operations of ECMAScript 262's `String.prototype` — full **capability** coverage of the spec's string operations, expressed in Zig's own idioms rather than a syntactic mimicry of JavaScript's dynamic object model (see [Zig Idioms vs JavaScript Syntax](#zig-idioms-vs-javascript-syntax) below for what that distinction means and why it matters). Designed to be the foundation for JavaScript/ECMAScript runtime engines written in Zig.

## 🎯 Project Goals

- **Spec Coverage**: Provide a Zig-idiomatic equivalent for every `String.prototype` operation ECMAScript 262 defines
- **UTF-16 Indexing**: Use UTF-16 code units for indexing (like JavaScript)
- **Performance**: Efficient implementation leveraging Zig's strengths
- **Runtime Ready**: Built to be integrated into ECMAScript runtime engines

## ✨ Features

### ✅ Implemented

Every method below is a real, independently-tested Zig function — this is
NOT a percentage of "spec compliance" (that would mean matching ECMA-262's
exact edge-case behavior, verified against a real conformance suite like
Test262; see [Known Gaps](#-known-gaps) for what's honestly missing on that
front). It's a coverage count of named operations.

#### Character Access (4 methods)
- `charAt(index)` - Get character at index
- `at(index)` - Get character with negative indexing support
- `charCodeAt(index)` - Get UTF-16 code unit value
- `codePointAt(index)` - Get Unicode code point

#### Search (5 methods)
- `indexOf(searchString, position?)` - Find first occurrence
- `lastIndexOf(searchString, position?)` - Find last occurrence
- `includes(searchString, position?)` - Check if contains substring
- `startsWith(searchString, position?)` - Check if starts with substring
- `endsWith(searchString, length?)` - Check if ends with substring

#### Transform (4 methods)
- `slice(start, end?)` - Extract substring with negative indices
- `substring(start, end?)` - Extract substring (swaps if start > end)
- `concat(...strings)` - Concatenate strings
- `repeat(count)` - Repeat string N times

#### Padding (2 methods)
- `padStart(targetLength, padString?)` - Pad from start
- `padEnd(targetLength, padString?)` - Pad from end

#### Trimming (5 methods)
- `trim()` - Remove whitespace from both ends
- `trimStart() / trimLeft()` - Remove whitespace from start
- `trimEnd() / trimRight()` - Remove whitespace from end

#### Split (1 method — see also `splitRegex` under Regex Methods)
- `split(separator?, limit?)` - Split string into array by a literal separator

#### Case Conversion (4 methods)
- `toLowerCase()` - Convert to lowercase
- `toUpperCase()` - Convert to uppercase
- `toLocaleLowerCase(locale?)` - Locale-aware lowercase*
- `toLocaleUpperCase(locale?)` - Locale-aware uppercase*

#### Utility (4 methods)
- `toStringAlloc()` - Get string value
- `valueOfAlloc()` - Get primitive value
- `localeCompare(that, locales?, options?)` - Compare strings*
- `normalize(form?)` - Unicode normalization (NFC/NFD/NFKC/NFKD)**

\* Basic implementation without full locale support (ICU integration planned)

\*\* Supports common Latin characters (À-ÿ range) with proper decomposition/composition

#### Static Factories (2 methods)
- `ZString.fromCharCode(code_units)` - Build a string from UTF-16 code units (combines surrogate pairs)
- `ZString.fromCodePoint(code_points)` - Build a string from full Unicode code points

Both live directly on `ZString` (constructors, same as `init`/`initOwned`/
`fromOwned`), not in `methods/`. Both take a slice instead of JS's
variadic `...args` (Zig has no variadic parameters — see
[Zig Idioms vs JavaScript Syntax](#zig-idioms-vs-javascript-syntax)), and
both error on an unpaired surrogate rather than silently building a
string z-string's UTF-8 storage can't actually represent (see
[WELL_FORMED_STRINGS.md](WELL_FORMED_STRINGS.md) for why) — stricter
than real JS, which allows it.

#### Regex Methods (6 methods) ✅
- `searchRegex(pattern)` - Search with regex
- `matchRegex(pattern)` - Match with regex
- `matchAllRegex(pattern)` - Match all with regex
- `replaceRegex(pattern, replaceValue)` - Replace with regex support*
- `replaceAllRegex(pattern, replaceValue)` - Replace all with regex support*
- `splitRegex(pattern, limit?)` - Split by a regex separator (see [Zig Idioms vs JavaScript Syntax](#zig-idioms-vs-javascript-syntax) for why this isn't just another `split()` overload — Zig has no function overloading)

All six carry a `*Regex` suffix rather than reusing the plain ECMAScript
names (`search`, `match`, `matchAll`, `replace`, `replaceAll`) — see
[Zig Idioms vs JavaScript Syntax](#zig-idioms-vs-javascript-syntax) for why
z-string doesn't overload the non-regex methods for this.

\* `replaceRegex`/`replaceAllRegex` always compile `pattern` as a regex,
even when you intend a literal substring — if your search string contains
regex metacharacters (`.`, `+`, `*`, etc.) they'll be interpreted as regex
syntax instead of matched literally. Escape them yourself if that matters,
or see [Known Gaps](#-known-gaps).

## 📦 Installation

### Language Support

z-string is a native Zig library — see [Quick Start](#-quick-start) below.

### Dependencies

z-string depends on [zregex](https://github.com/carlos-sweb/z-regex) for regex functionality, pinned as a git dependency in `build.zig.zon`:
```zig
.dependencies = .{
    .zregex = .{
        .url = "git+https://github.com/carlos-sweb/z-regex.git#<commit>",
        .hash = "zregex-...",
    },
},
```
`zig build` fetches it automatically on first run (into a local `zig-pkg/`
directory, per Zig 0.16's package layout) — no manual cloning or sibling
checkout required. To move to a different zregex commit:
```bash
zig fetch --save git+https://github.com/carlos-sweb/z-regex.git
```
This rewrites the `.zregex` entry in `build.zig.zon` with the new commit's
URL and hash.

#### Quick Setup (Local Development)

```bash
git clone https://github.com/carlos-sweb/z-string.git
cd z-string
zig build test   # fetches zregex automatically
```

#### Future: Package Manager Installation

Once published, you'll be able to add to your `build.zig.zon`:

```zig
.{
    .name = .my_project,          // Zig 0.16 requires an enum literal, not a string
    .version = "0.1.0",
    .fingerprint = 0x...,          // Zig 0.16 requires this; `zig build` will generate it
    .dependencies = .{
        .zstring = .{
            .url = "https://github.com/carlos-sweb/z-string/archive/refs/tags/v0.2.0.tar.gz",
            .hash = "1220...", // Use zig fetch to get hash
        },
    },
}
```

Add to your `build.zig`:

```zig
const zstring = b.dependency("zstring", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zstring", zstring.module("zstring"));
```

### Manual Installation

```bash
git clone https://github.com/carlos-sweb/z-string.git
cd z-string
zig build test
```

## ⚠️ Error Handling

z-string follows Zig's error handling philosophy. All operations that can fail return error unions:

```zig
// ✅ Proper error handling
const upper = try str.toUpperCase(allocator);
defer allocator.free(upper);

// ✅ Handle specific errors
const result = str.toUpperCase(allocator) catch |err| {
    std.log.err("Failed: {}", .{err});
    return err;
};

// ✅ Check optional returns
const char = try str.at(allocator, 0);
if (char) |c| {
    defer allocator.free(c);
    // Use c...
}
```

**📖 See [ERROR_HANDLING.md](ERROR_HANDLING.md) for comprehensive error handling guide.**

## 🚀 Quick Start

### Zig API

```zig
const std = @import("std");
const zstring = @import("zstring");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a ZString
    const str = zstring.ZString.init("Hello, World!");

    // Character access
    const char = try str.charAt(allocator, 0);
    defer allocator.free(char);
    std.debug.print("First char: {s}\n", .{char}); // "H"

    // Search
    const pos = str.indexOf("World", null);
    std.debug.print("Position: {}\n", .{pos}); // 7

    // Transform
    const upper = try str.toUpperCase(allocator);
    defer allocator.free(upper);
    std.debug.print("Upper: {s}\n", .{upper}); // "HELLO, WORLD!"

    // Split (literal separator)
    const parts = try str.split(allocator, ", ", null);
    defer zstring.ZString.freeSplitResult(allocator, parts);
    std.debug.print("Parts: {s}, {s}\n", .{parts[0], parts[1]}); // "Hello", "World!"

    // Split (regex separator) -- a sibling function, not an overload of
    // split() -- see "Zig Idioms vs JavaScript Syntax" below.
    const digits = zstring.ZString.init("a1b2c3");
    const pieces = try digits.splitRegex(allocator, "[0-9]+", null);
    defer zstring.ZString.freeSplitResult(allocator, pieces);
    std.debug.print("Pieces: {s}, {s}, {s}\n", .{pieces[0], pieces[1], pieces[2]}); // "a", "b", "c"
}
```

## 🧩 Composing with the z-* ecosystem

z-string depends on nothing but `zregex` (and only for the methods that
actually need real regex matching). It does NOT depend on `z-array`,
`z-value`, or anything else in the wider `z-*` family — that's
deliberate, not an oversight. `split()`/`splitRegex()` already return
everything you need (`[][]u8`, a plain Zig slice) to build a richer
container yourself, on the consumer side, with zero changes to this
library:

```zig
const std = @import("std");
const zstring = @import("zstring");
const zarray = @import("zarray");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const str = zstring.ZString.init("hola, a, todos");
    const words = try zarray.ZArray([]const u8).fromSlice(
        allocator,
        try str.split(allocator, ", ", null),
    );
    // words is now a real ZArray([]const u8) -- push/pop/map/filter/etc.
    // all available, on top of what split() already gave you.
}
```

**Why z-string doesn't just depend on z-array and return `ZArray`
directly:** it would only save the one `fromSlice` copy above, at the
cost of a real dependency edge pointed the wrong way for what's likely
to come next. `ZArray`'s own `join()`/`toString()` want to turn their
elements back into text -- which is exactly z-string's job. Depend
`z-string -> z-array` today and there's a real chance of wanting
`z-array -> z-string` (or `-> z-value`) tomorrow for that, and now
you're negotiating a cycle instead of composing two libraries. Keeping
the dependency arrow one-directional (or absent, as here) means either
side can be used completely on its own -- you reach for both only when
YOUR code wants both, and z-string never has to care that z-array
exists.

## 📚 Documentation

### Key Concepts

#### Zig Idioms vs JavaScript Syntax

z-string targets **functional equivalence** with `String.prototype`, not
syntactic mimicry — some of what reads as a single, flexible JavaScript
method is deliberately split across several Zig functions, because Zig
doesn't support what JavaScript relies on to make that flexibility work:

- **No function overloading.** `"a,b".split(",")` and `"a1b".split(/\d/)`
  are the same JS method dispatching on the argument's runtime type.
  Zig can't do that — there's no way to have two functions named `split`
  distinguished only by parameter type. So a literal separator uses
  `split()`, and a regex separator uses the sibling function
  `splitRegex()`. Same pattern elsewhere in this library: `toUpperCase()`
  vs `toLocaleUpperCase()`, and the regex-backed methods
  (`searchRegex()`/`matchRegex()`/`matchAllRegex()`/`replaceRegex()`/
  `replaceAllRegex()`) are all named with an explicit `Regex` suffix
  rather than overloading `search`/`match`/`replace` from the spec.
- **No dynamic `[]` indexing on custom types.** JS's `new String("abc")[0]`
  relies on the language auto-exposing indexed properties on an object.
  Zig has no operator overloading for that. The equivalent capability is
  `str.at(allocator, 0)` — same result, explicit call instead of bracket
  syntax.

If you're coming from JS and expect one method name per spec operation,
this is the one thing to unlearn: **the library grows by adding a new,
clearly-named function, not by overloading an existing one.**

#### UTF-16 Indexing

JavaScript uses UTF-16 code units for string indexing. z-string maintains this behavior for spec compliance:

```zig
const str = zstring.ZString.init("😀"); // Emoji (surrogate pair)
std.debug.print("Length: {}\n", .{str.length()}); // 2 (UTF-16 code units)
```

#### Memory Management

Methods that return new strings require explicit memory management:

```zig
const upper = try str.toUpperCase(allocator);
defer allocator.free(upper); // Caller owns the memory
```

Accumulating several results before combining them (e.g. building up parts
of a string) uses Zig 0.16's unmanaged `std.ArrayList` — initialize with
`.empty`, and pass the allocator explicitly to `append`/`deinit` (there is
no `.init(allocator)` shorthand anymore):

```zig
var parts: std.ArrayList([]const u8) = .empty;
defer {
    for (parts.items) |part| allocator.free(part);
    parts.deinit(allocator);
}

try parts.append(allocator, try str1.toUpperCase(allocator));
try parts.append(allocator, try str2.toUpperCase(allocator));
```

See `examples/error_handling.zig` (`safeStringBuilder`, run via
`zig build example-errors`) for this in context.

#### Borrowed vs Owned Strings

```zig
// Borrowed (no allocation)
const borrowed = zstring.ZString.init("hello");

// Owned (allocated, must call deinit)
var owned = try zstring.ZString.initOwned(allocator, "hello");
defer owned.deinit();
```

### Examples

See the `examples/` directory for complete examples:
- `character_access.zig` - Character access methods
- `search_methods.zig` - Search and indexOf methods
- `transform_methods.zig` - Slice, substring, concat, repeat
- `padding_trimming_methods.zig` - Padding and trimming
- `split_method.zig` - String splitting
- `error_handling.zig` - Error handling patterns (try/catch, errdefer, ArrayList-based string building)

Run examples:
```bash
zig build example              # Character access
zig build example-search       # Search methods
zig build example-transform    # Transform methods
zig build example-padding-trimming
zig build example-split
zig build example-errors       # Error handling (recommended!)
```

## 🧪 Testing

```bash
# Run all tests
zig build test

# Run benchmarks
zig build bench
```

**Test Coverage:**
- 372+ tests across all implemented methods
- ECMAScript spec compliance tests
- Unicode and emoji handling tests
- Unicode normalization tests (NFC/NFD/NFKC/NFKD)
- Edge case coverage

## 🏗️ Architecture

```
z-string/
├── src/
│   ├── zstring.zig           # Public Zig API entry point
│   ├── core/
│   │   ├── utf16.zig         # UTF-8 ↔ UTF-16 conversion
│   │   └── string.zig        # ZString struct
│   └── methods/              # Method implementations (grouped by category)
│       ├── access.zig        # charAt, at, charCodeAt, codePointAt
│       ├── search.zig        # indexOf, lastIndexOf, includes, etc.
│       ├── transform.zig     # slice, substring, concat, repeat
│       ├── padding.zig       # padStart, padEnd
│       ├── trimming.zig      # trim, trimStart, trimEnd
│       ├── split.zig         # split
│       ├── case.zig          # toLowerCase, toUpperCase
│       ├── regex.zig         # search, match, matchAll, replace, replaceAll, splitRegex
│       ├── unicode_normalize.zig  # NFC/NFD/NFKC/NFKD normalization
│       └── utility.zig       # toString, valueOf, localeCompare, normalize
├── tests/
│   ├── spec/                 # ECMAScript spec compliance tests
│   └── benchmarks/           # Performance benchmarks
└── examples/                 # Usage examples
```

## 🔮 Roadmap

### Phase 1: Core Methods ✅ (Complete)
- [x] Character access methods
- [x] Search methods (literal)
- [x] Transform methods
- [x] Padding and trimming
- [x] Split (literal)
- [x] Case conversion
- [x] Utility methods
- [x] Unicode normalization (NFC/NFD/NFKC/NFKD)

### Phase 2: Regex Integration ✅ (Complete)
- [x] Integrate zregex as dependency
- [x] Implement search() with regex
- [x] Implement match() and matchAll()
- [x] Implement replace() and replaceAll() with regex
- [x] Implement splitRegex() (regex-separator split, sibling of split())
- [x] Comprehensive test coverage for regex methods

### Phase 3: Advanced Features 🔮 (Future)

See [PHASE3_ANALYSIS.md](PHASE3_ANALYSIS.md) for a complexity breakdown
of these three — they are NOT the same size (locale-aware case mapping
is bounded and cheap; full UCD normalization and real ICU collation are
each a project of their own).

- [ ] Full locale support (ICU integration)
- [ ] Extended Unicode normalization (full UCD coverage beyond Latin-1)
- [ ] Locale-aware case mapping (Turkish İ/i, etc.)
- [x] Static factories: `ZString.fromCharCode`, `ZString.fromCodePoint`
- [ ] `String.raw` (needs a tagged-template-literal caller, out of scope for a pure string-ops library on its own)
- [ ] `toWellFormed()` (the fix-up counterpart to the existing `isWellFormed()` check)
- [ ] `replace`/`replaceAll` treating a plain (non-regex) search string as a literal match instead of always compiling it as a pattern

## ⚠️ Known Gaps

Honest list of ECMA-262 `String.prototype` **capabilities** with no
equivalent in z-string yet (see [Zig Idioms vs JavaScript Syntax](#zig-idioms-vs-javascript-syntax)
for why "capability" and "same method name" are different questions):

- **`toWellFormed()` / real `isWellFormed()`** — deeper than a missing
  method; the current `[]const u8` (standard UTF-8) storage can't even
  represent the lone-surrogate case these two are supposed to detect.
  Full writeup, including what a real fix requires, in
  [WELL_FORMED_STRINGS.md](WELL_FORMED_STRINGS.md).
- **`String.raw`** — no equivalent; it's inherently tied to a
  tagged-template-literal call site (the raw, unescaped source text of
  the template), which doesn't have a meaningful counterpart in a
  standalone string-operations library.
- **`replace()`/`replaceAll()` literal-search correctness** — both always
  compile their search argument as a regex pattern. A search string
  containing regex metacharacters (`.`, `+`, `*`, `?`, ...) will be
  interpreted as regex syntax rather than matched literally — e.g.
  searching for the literal text `"3.14"` also matches `"3X14"` for any
  character `X`, because `.` means "any character" once compiled.

This list is a byproduct of an actual capability audit against ECMA-262
§22.1.3, not a percentage estimate — if you find something else missing,
open an issue and it'll get added here.

## 🤝 Contributing

Contributions are welcome! This project is actively maintained.

### Development Setup

```bash
git clone https://github.com/carlos-sweb/z-string.git
cd z-string
zig build test
```

### Guidelines

- Follow ECMAScript 262 specification exactly
- Maintain UTF-16 indexing compatibility
- Include comprehensive tests for all changes
- Document public APIs with examples

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- **[zregex](https://github.com/carlos-sweb/z-regex)** - Zig regex engine for ECMAScript compatibility; z-string's only dependency, used for all `*Regex` methods
- **Zig Standard Library** - UTF-8/UTF-16 utilities

## 📊 Project Status

**Current Version:** 0.5.0

**Coverage:** every `String.prototype` operation from ECMA-262 §22.1.3 has
a Zig-idiomatic equivalent in this library, EXCEPT the items listed under
[Known Gaps](#-known-gaps) above (`String.raw`, `toWellFormed()`, and the
replace/replaceAll literal-search caveat). "Coverage" here means
"a real function exists for it" — it is deliberately NOT a spec-compliance
percentage. This library doesn't run against Test262 (ECMAScript's actual
conformance suite) on its own; the only end-to-end conformance numbers
that exist are measured downstream, through a full JS engine that
consumes z-string, and reflect that engine's plumbing as much as this
library's own correctness.

✅ **Project Status: ACTIVE**

**Dependency Architecture:**
- z-string depends on zregex (one-way dependency)
- No circular dependencies
- Clean separation of concerns

## 🙏 Acknowledgments

- ECMAScript 262 specification
- Zig community
- All contributors

---

**Note:** For questions or discussions about the project architecture, please open an issue.
