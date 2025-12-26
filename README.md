# z-string

**ECMAScript String API implementation in Zig**

[![Zig Version](https://img.shields.io/badge/zig-0.15.2-orange.svg)](https://ziglang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-paused-yellow.svg)](#-project-status)

A Zig library that implements the ECMAScript 262 String API with full spec compliance. Designed to be the foundation for JavaScript/ECMAScript runtime engines written in Zig.

## 🎯 Project Goals

- **Spec Compliance**: Match ECMAScript 262 String API behavior exactly
- **UTF-16 Indexing**: Use UTF-16 code units for indexing (like JavaScript)
- **Performance**: Efficient implementation leveraging Zig's strengths
- **Runtime Ready**: Built to be integrated into ECMAScript runtime engines

## ✨ Features

### ✅ Implemented (27/33 methods - 81.8%)

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

#### Split (1 method)
- `split(separator?, limit?)` - Split string into array

#### Case Conversion (4 methods)
- `toLowerCase()` - Convert to lowercase
- `toUpperCase()` - Convert to uppercase
- `toLocaleLowerCase(locale?)` - Locale-aware lowercase*
- `toLocaleUpperCase(locale?)` - Locale-aware uppercase*

#### Utility (3 methods)
- `toString()` - Get string value
- `valueOf()` - Get primitive value
- `localeCompare(that, locales?, options?)` - Compare strings*
- `normalize(form?)` - Unicode normalization**

\* Basic implementation without full locale support (ICU integration planned)

\*\* Placeholder implementation (full Unicode normalization requires UCD)

### ⏳ Pending (5 methods - require regex engine)

These methods require **libzregexp** (Zig regex engine, in development):
- `search(regexp)` - Search with regex
- `match(regexp)` - Match with regex
- `matchAll(regexp)` - Match all with regex
- `replace(searchValue, replaceValue)` - Replace with regex support
- `replaceAll(searchValue, replaceValue)` - Replace all with regex support

## 📦 Installation

### Using Zig Package Manager (0.15.0+)

Add to your `build.zig.zon`:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .zstring = .{
            .url = "https://github.com/YOUR_USERNAME/z-string/archive/refs/tags/v0.1.0.tar.gz",
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
git clone https://github.com/YOUR_USERNAME/z-string.git
cd z-string
zig build test
```

## 🚀 Quick Start

```zig
const std = @import("std");
const zstring = @import("zstring");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
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

    // Split
    const parts = try str.split(allocator, ", ", null);
    defer zstring.ZString.freeSplitResult(allocator, parts);
    std.debug.print("Parts: {s}, {s}\n", .{parts[0], parts[1]}); // "Hello", "World!"
}
```

## 📚 Documentation

### Key Concepts

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

Run examples:
```bash
zig build example              # Character access
zig build example-search       # Search methods
zig build example-transform    # Transform methods
zig build example-padding-trimming
zig build example-split
```

## 🧪 Testing

```bash
# Run all tests
zig build test

# Run benchmarks
zig build bench
```

**Test Coverage:**
- 260+ tests across all implemented methods
- ECMAScript spec compliance tests
- Unicode and emoji handling tests
- Edge case coverage

## 🏗️ Architecture

```
z-string/
├── src/
│   ├── zstring.zig           # Public API entry point
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
│       └── utility.zig       # toString, valueOf, localeCompare, normalize
├── tests/
│   ├── spec/                 # ECMAScript spec compliance tests
│   └── benchmarks/           # Performance benchmarks
└── examples/                 # Usage examples
```

## 🔮 Roadmap

### Phase 1: Core Methods ✅ (Current - 96.4% complete)
- [x] Character access methods
- [x] Search methods (literal)
- [x] Transform methods
- [x] Padding and trimming
- [x] Split (literal)
- [x] Case conversion
- [x] Utility methods

### Phase 2: Regex Integration ⏸️ (Paused - pending libzregexp analysis)
- [ ] Analyze libzregexp requirements
- [ ] Determine optimal dependency strategy
- [ ] Implement search() with regex
- [ ] Implement match() and matchAll()
- [ ] Implement replace() and replaceAll() with regex

### Phase 3: Advanced Features 🔮 (Future)
- [ ] Full locale support (ICU integration)
- [ ] Complete Unicode normalization (UCD integration)
- [ ] Locale-aware case mapping (Turkish İ/i, etc.)

## 🤝 Contributing

Contributions are welcome! This project is currently paused pending libzregexp analysis.

### Development Setup

```bash
git clone https://github.com/YOUR_USERNAME/z-string.git
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

- **libzregexp** (in development) - Zig regex engine for ECMAScript compatibility
- **Zig Standard Library** - UTF-8/UTF-16 utilities

## 📊 Project Status

**Current Version:** 0.1.0 (Development)

**Compatibility:**
- ✅ 27/28 non-regex methods implemented (96.4%)
- ✅ 27/33 total methods (81.8%)
- ⏳ 5 regex methods pending libzregexp

**Production Ready:** Not yet - active development phase

⏸️ **Project Status: PAUSED**

This project is temporarily paused pending analysis of **libzregexp** requirements. Before proceeding with regex method implementation, we need to:

1. Analyze what string manipulation features libzregexp requires
2. Determine optimal dependency strategy to avoid circular dependencies
3. Decide on architecture: separate z-string-core vs monolithic approach

The decision to pause is intentional - implementing the wrong architecture now would require costly refactoring later. Once libzregexp requirements are clear, development will resume with a solid foundation.

## 🙏 Acknowledgments

- ECMAScript 262 specification
- Zig community
- All contributors

---

**Note:** For questions or discussions about the project architecture, please open an issue.
