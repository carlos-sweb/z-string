# Using z-string from C++

This guide explains how to use **z-string** from C++ programs. z-string provides a complete ECMAScript 262 String API implementation through a modern C++ interface with RAII, exceptions, and STL integration.

## Table of Contents

- [Installation](#installation)
- [Building](#building)
- [Quick Start](#quick-start)
- [Memory Management](#memory-management)
- [Error Handling](#error-handling)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Best Practices](#best-practices)

---

## Installation

### Prerequisites

- Zig 0.15.2 or later
- C++17 compiler (g++, clang++, MSVC)

### Building the C++ Library

```bash
# Clone the repository
git clone https://github.com/carlos-sweb/z-string.git
cd z-string

# Build the library
zig build-lib src/c_api.zig -target native -O ReleaseFast

# This will create libzstring.a (static) or libzstring.so (dynamic)
```

### Linking in Your Project

**Static linking:**
```bash
g++ -std=c++17 your_program.cpp -I./include -L. -lzstring -o your_program
```

**Dynamic linking:**
```bash
g++ -std=c++17 your_program.cpp -I./include -L. -lzstring -Wl,-rpath,. -o your_program
```

---

## Quick Start

Here's a simple example to get you started:

```cpp
#include <iostream>
#include "zstring.hpp"

int main() {
    try {
        // Create a string (RAII - automatic cleanup)
        zstring::String str("Hello, World!");

        // Get the length
        std::cout << "Length: " << str.length() << std::endl;

        // Convert to uppercase
        auto upper = str.toUpperCase();
        std::cout << "Uppercase: " << upper << std::endl;

        // Search for substring
        auto pos = str.indexOf("World");
        std::cout << "Position: " << pos << std::endl;

        // Split into words
        auto words = str.split(" ");
        for (const auto& word : words) {
            std::cout << "Word: " << word << std::endl;
        }

    } catch (const zstring::Exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
```

**Output:**
```
Length: 13
Uppercase: HELLO, WORLD!
Position: 7
Word: Hello,
Word: World!
```

---

## Memory Management

The C++ API uses **RAII (Resource Acquisition Is Initialization)** for automatic memory management.

### Automatic Cleanup

```cpp
{
    zstring::String str("Hello");  // Constructor acquires resources

    auto upper = str.toUpperCase();  // Returns std::string (managed by STL)

    // No manual cleanup needed!

} // Destructor automatically frees resources
```

### Move Semantics

```cpp
// Move construction (efficient, no copy)
zstring::String str1("Hello");
zstring::String str2(std::move(str1));  // str1 is now empty

// Move assignment
zstring::String str3("World");
str3 = std::move(str2);  // str2 is now empty
```

### No Copy Allowed

```cpp
// ❌ Copy is disabled to prevent accidental expensive operations
zstring::String str1("Hello");
// zstring::String str2 = str1;  // Compile error!

// ✅ Instead, use toString() if you need a copy
std::string copy = str1.toString();
```

---

## Error Handling

The C++ API uses **exceptions** for error handling, making code cleaner and more idiomatic.

### Exception Class

```cpp
namespace zstring {
    class Exception : public std::runtime_error {
    public:
        ZStringError error_code() const noexcept;
    };
}
```

### Catching Exceptions

```cpp
try {
    zstring::String str("test");
    auto ch = str.charAt(100);  // Out of bounds

} catch (const zstring::Exception& e) {
    std::cerr << "z-string error: " << e.what() << std::endl;
    std::cerr << "Error code: " << e.error_code() << std::endl;

} catch (const std::exception& e) {
    std::cerr << "Standard exception: " << e.what() << std::endl;
}
```

### Exceptions vs Optional

Some methods return `std::optional` instead of throwing:

```cpp
zstring::String str("Hello");

// at() returns optional (nullptr is valid for out of bounds)
auto maybe_char = str.at(-1);
if (maybe_char) {
    std::cout << "Last char: " << *maybe_char << std::endl;
} else {
    std::cout << "Index out of bounds" << std::endl;
}
```

---

## API Reference

### Construction and Conversion

#### Constructor
```cpp
zstring::String str("Hello");           // From C string
zstring::String str(std::string("Hi")); // From std::string
```

#### `toString()`
```cpp
std::string toString() const;
```
Convert to `std::string`.

**Example:**
```cpp
zstring::String str("Hello");
std::string s = str.toString();
// or implicit conversion:
std::string s2 = str;
```

#### `length()`
```cpp
size_t length() const;
```
Get length in UTF-16 code units (like JavaScript `.length`).

---

### Character Access

#### `charAt(size_t index)`
```cpp
std::string charAt(size_t index) const;
```
Get character at index (String.prototype.charAt).

**Example:**
```cpp
zstring::String str("Hello");
auto ch = str.charAt(0);  // "H"
```

#### `at(int64_t index)`
```cpp
std::optional<std::string> at(int64_t index) const;
```
Get character with negative indexing (String.prototype.at).

**Example:**
```cpp
zstring::String str("Hello");
auto last = str.at(-1);  // std::optional<std::string> containing "o"
if (last) {
    std::cout << *last << std::endl;
}
```

#### `charCodeAt(size_t index)`
```cpp
uint16_t charCodeAt(size_t index) const;
```
Get UTF-16 code unit at index.

**Example:**
```cpp
zstring::String str("A");
auto code = str.charCodeAt(0);  // 65
```

#### `codePointAt(size_t index)`
```cpp
uint32_t codePointAt(size_t index) const;
```
Get Unicode code point at index.

**Example:**
```cpp
zstring::String str("😀");
auto cp = str.codePointAt(0);  // 0x1F600
```

---

### Search Methods

#### `indexOf(const std::string& search_str, int64_t position = 0)`
```cpp
int64_t indexOf(const std::string& search_str, int64_t position = 0) const;
```
Find first occurrence. Returns -1 if not found.

**Example:**
```cpp
zstring::String str("Hello, World!");
auto pos = str.indexOf("World");  // 7
```

#### `lastIndexOf(const std::string& search_str, int64_t position = -1)`
```cpp
int64_t lastIndexOf(const std::string& search_str, int64_t position = -1) const;
```
Find last occurrence.

#### `includes(const std::string& search_str, int64_t position = 0)`
```cpp
bool includes(const std::string& search_str, int64_t position = 0) const;
```
Check if contains substring.

**Example:**
```cpp
if (str.includes("World")) {
    std::cout << "Contains 'World'" << std::endl;
}
```

#### `startsWith(const std::string& search_str, int64_t position = 0)`
```cpp
bool startsWith(const std::string& search_str, int64_t position = 0) const;
```
Check if starts with substring.

#### `endsWith(const std::string& search_str, int64_t length = -1)`
```cpp
bool endsWith(const std::string& search_str, int64_t length = -1) const;
```
Check if ends with substring.

---

### Transform Methods

#### `slice(int64_t start, int64_t end = INT64_MAX)`
```cpp
std::string slice(int64_t start, int64_t end = INT64_MAX) const;
```
Extract substring with negative indices support.

**Example:**
```cpp
zstring::String str("Hello, World!");
auto sub = str.slice(0, 5);      // "Hello"
auto last3 = str.slice(-3);      // "ld!"
```

#### `substring(size_t start, size_t end = SIZE_MAX)`
```cpp
std::string substring(size_t start, size_t end = SIZE_MAX) const;
```
Extract substring (swaps if start > end).

#### `concat(const std::vector<std::string>& strings)`
```cpp
std::string concat(const std::vector<std::string>& strings) const;
```
Concatenate multiple strings.

**Example:**
```cpp
zstring::String str("Hello");
auto result = str.concat({", ", "World", "!"});  // "Hello, World!"
```

#### `repeat(size_t count)`
```cpp
std::string repeat(size_t count) const;
```
Repeat string N times.

**Example:**
```cpp
zstring::String str("abc");
auto result = str.repeat(3);  // "abcabcabc"
```

---

### Padding Methods

#### `padStart(size_t target_length, const std::string& pad_str = " ")`
```cpp
std::string padStart(size_t target_length, const std::string& pad_str = " ") const;
```
Pad string from start.

**Example:**
```cpp
zstring::String str("5");
auto padded = str.padStart(3, "0");  // "005"
```

#### `padEnd(size_t target_length, const std::string& pad_str = " ")`
```cpp
std::string padEnd(size_t target_length, const std::string& pad_str = " ") const;
```
Pad string from end.

---

### Trimming Methods

#### `trim()`
```cpp
std::string trim() const;
```
Remove whitespace from both ends.

**Example:**
```cpp
zstring::String str("  hello  ");
auto trimmed = str.trim();  // "hello"
```

#### `trimStart()` / `trimLeft()`
```cpp
std::string trimStart() const;
```
Remove whitespace from start.

#### `trimEnd()` / `trimRight()`
```cpp
std::string trimEnd() const;
```
Remove whitespace from end.

---

### Split Method

#### `split(const std::string& separator, size_t limit = 0)`
```cpp
std::vector<std::string> split(const std::string& separator, size_t limit = 0) const;
```
Split string into vector.

**Example:**
```cpp
zstring::String str("a,b,c");
auto parts = str.split(",");
// parts = {"a", "b", "c"}

for (const auto& part : parts) {
    std::cout << part << std::endl;
}
```

#### `split(size_t limit = 0)` (no separator)
```cpp
std::vector<std::string> split(size_t limit = 0) const;
```
Split into individual characters.

**Example:**
```cpp
zstring::String str("abc");
auto chars = str.split();
// chars = {"a", "b", "c"}
```

---

### Case Conversion

#### `toLowerCase()`
```cpp
std::string toLowerCase() const;
```
Convert to lowercase.

**Example:**
```cpp
zstring::String str("HELLO");
auto lower = str.toLowerCase();  // "hello"
```

#### `toUpperCase()`
```cpp
std::string toUpperCase() const;
```
Convert to uppercase.

**Example:**
```cpp
zstring::String str("hello");
auto upper = str.toUpperCase();  // "HELLO"
```

---

### Utility Methods

#### `localeCompare(const std::string& that)`
```cpp
int64_t localeCompare(const std::string& that) const;
```
Compare strings. Returns negative, 0, or positive.

**Example:**
```cpp
zstring::String str("apple");
auto cmp = str.localeCompare("banana");  // negative
```

#### `normalize(const std::string& form = "NFC")`
```cpp
std::string normalize(const std::string& form = "NFC") const;
```
Unicode normalization (NFC, NFD, NFKC, NFKD).

**Example:**
```cpp
zstring::String str("café");
auto nfc = str.normalize("NFC");   // Composed form
auto nfd = str.normalize("NFD");   // Decomposed form
```

---

### Regex Methods

#### `search(const std::string& pattern)`
```cpp
int64_t search(const std::string& pattern) const;
```
Search with regex. Returns index or -1.

**Example:**
```cpp
zstring::String str("The price is $123");
auto pos = str.search("\\$\\d+");  // 13
```

#### `match(const std::string& pattern)`
```cpp
std::vector<std::string> match(const std::string& pattern) const;
```
Match with regex.

**Example:**
```cpp
zstring::String str("123-456-7890");
auto matches = str.match("\\d+");
// matches = {"123", "456", "7890"}
```

#### `replace(const std::string& search_value, const std::string& replace_value)`
```cpp
std::string replace(const std::string& search_value,
                   const std::string& replace_value) const;
```
Replace first match.

**Example:**
```cpp
zstring::String str("Hello World");
auto result = str.replace("World", "C++");  // "Hello C++"
```

#### `replaceAll(const std::string& search_value, const std::string& replace_value)`
```cpp
std::string replaceAll(const std::string& search_value,
                      const std::string& replace_value) const;
```
Replace all matches.

**Example:**
```cpp
zstring::String str("foo bar foo");
auto result = str.replaceAll("foo", "baz");  // "baz bar baz"
```

---

## Examples

### Example 1: Text Processing Pipeline

```cpp
#include <iostream>
#include <algorithm>
#include "zstring.hpp"

int main() {
    try {
        zstring::String text("  Hello, WORLD!  ");

        // Chain operations (fluent interface via intermediate strings)
        auto trimmed = text.trim();
        zstring::String temp1(trimmed);

        auto lower = temp1.toLowerCase();
        zstring::String temp2(lower);

        auto words = temp2.split(" ");

        std::cout << "Words:" << std::endl;
        for (const auto& word : words) {
            std::cout << "  - " << word << std::endl;
        }

    } catch (const zstring::Exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
```

### Example 2: Character Analysis

```cpp
#include <iostream>
#include <iomanip>
#include "zstring.hpp"

void analyze_string(const std::string& input) {
    try {
        zstring::String str(input);

        std::cout << "String: " << str.toString() << std::endl;
        std::cout << "Length: " << str.length() << " UTF-16 code units" << std::endl;
        std::cout << std::endl;

        std::cout << "Characters:" << std::endl;
        for (size_t i = 0; i < str.length(); i++) {
            auto ch = str.charAt(i);
            auto cp = str.codePointAt(i);

            std::cout << "  [" << i << "] '" << ch << "' "
                     << "U+" << std::hex << std::uppercase
                     << std::setw(4) << std::setfill('0') << cp
                     << std::dec << std::endl;
        }

    } catch (const zstring::Exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }
}

int main() {
    analyze_string("Hello 😀");
    return 0;
}
```

### Example 3: String Validation

```cpp
#include <iostream>
#include "zstring.hpp"

bool is_valid_email(const std::string& email) {
    zstring::String str(email);

    // Simple email validation
    auto at_pos = str.indexOf("@");
    if (at_pos < 1) return false;

    auto dot_pos = str.lastIndexOf(".");
    if (dot_pos < at_pos + 2) return false;

    if (dot_pos >= static_cast<int64_t>(str.length()) - 2) return false;

    return true;
}

int main() {
    std::vector<std::string> emails = {
        "user@example.com",
        "invalid@",
        "@invalid.com",
        "valid.user@domain.org"
    };

    for (const auto& email : emails) {
        std::cout << email << ": "
                 << (is_valid_email(email) ? "Valid" : "Invalid")
                 << std::endl;
    }

    return 0;
}
```

### Example 4: Template Processing

```cpp
#include <iostream>
#include <map>
#include "zstring.hpp"

std::string process_template(const std::string& tmpl,
                            const std::map<std::string, std::string>& vars) {
    zstring::String result(tmpl);

    for (const auto& [key, value] : vars) {
        std::string placeholder = "{{" + key + "}}";
        auto replaced = result.replaceAll(placeholder, value);
        result = zstring::String(replaced);
    }

    return result.toString();
}

int main() {
    std::string tmpl = "Hello, {{name}}! You are {{age}} years old.";

    std::map<std::string, std::string> vars = {
        {"name", "Alice"},
        {"age", "30"}
    };

    auto output = process_template(tmpl, vars);
    std::cout << output << std::endl;
    // Output: Hello, Alice! You are 30 years old.

    return 0;
}
```

### Example 5: Regex Operations

```cpp
#include <iostream>
#include "zstring.hpp"

int main() {
    try {
        zstring::String text("The prices are $10, $20, and $30");

        // Search for pattern
        auto pos = text.search("\\$\\d+");
        std::cout << "First price at position: " << pos << std::endl;

        // Extract all prices
        auto prices = text.match("\\$\\d+");
        std::cout << "All prices:" << std::endl;
        for (const auto& price : prices) {
            std::cout << "  " << price << std::endl;
        }

        // Replace prices
        auto updated = text.replaceAll("\\$(\\d+)", "EUR$1");
        std::cout << "Updated: " << updated << std::endl;

    } catch (const zstring::Exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }

    return 0;
}
```

---

## Best Practices

### 1. Use RAII for Automatic Cleanup

```cpp
// ✅ Good - automatic cleanup
{
    zstring::String str("hello");
    // Use str...
} // Automatically freed

// ❌ Avoid manual resource management
```

### 2. Prefer Range-Based for Loops

```cpp
// ✅ Good
auto parts = str.split(",");
for (const auto& part : parts) {
    std::cout << part << std::endl;
}

// ❌ Avoid manual indexing when not needed
for (size_t i = 0; i < parts.size(); i++) {
    std::cout << parts[i] << std::endl;
}
```

### 3. Use Exceptions for Error Handling

```cpp
// ✅ Good - idiomatic C++
try {
    auto result = str.charAt(index);
    process(result);
} catch (const zstring::Exception& e) {
    handle_error(e);
}
```

### 4. Leverage Move Semantics

```cpp
// ✅ Good - efficient move
zstring::String str1("hello");
zstring::String str2(std::move(str1));  // No copy
```

### 5. Use const References

```cpp
// ✅ Good
void process_string(const zstring::String& str) {
    auto upper = str.toUpperCase();
    // ...
}

// ❌ Avoid unnecessary copies
void process_string(zstring::String str) {  // Copy!
    // ...
}
```

### 6. Chain with Intermediate Variables

```cpp
// ✅ Clear and readable
auto trimmed = str.trim();
zstring::String temp(trimmed);
auto upper = temp.toUpperCase();

// Alternative: One-liners when appropriate
auto result = zstring::String(str.trim()).toUpperCase();
```

---

## CMake Integration

Create a `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.15)
project(MyProject CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add z-string include directory
include_directories(${CMAKE_SOURCE_DIR}/z-string/include)

# Link z-string library
link_directories(${CMAKE_SOURCE_DIR}/z-string)

# Your executable
add_executable(my_app main.cpp)
target_link_libraries(my_app zstring)
```

Build:
```bash
mkdir build && cd build
cmake ..
make
```

---

## Compilation Tips

### Basic Compilation

```bash
g++ -std=c++17 -O2 main.cpp -I./include -L. -lzstring -o app
```

### With Warnings

```bash
g++ -std=c++17 -Wall -Wextra -O2 main.cpp -I./include -L. -lzstring -o app
```

### Debug Build

```bash
g++ -std=c++17 -g -O0 main.cpp -I./include -L. -lzstring -o app
```

### Link Static Library

```bash
g++ -std=c++17 main.cpp -I./include -L. -lzstring -static -o app
```

---

## Troubleshooting

### Linker Errors

```bash
# Make sure library path is correct
g++ main.cpp -I./include -L/path/to/library -lzstring
```

### Runtime Library Not Found

```bash
# Add to library path
export LD_LIBRARY_PATH=/path/to/library:$LD_LIBRARY_PATH

# Or use rpath
g++ main.cpp -I./include -L. -lzstring -Wl,-rpath,.
```

### Exception Safety

All methods provide strong exception safety guarantee:
- If an exception is thrown, no resources are leaked
- RAII ensures cleanup even during stack unwinding

---

## Performance Tips

1. **Use move semantics** for large strings
2. **Reserve vector capacity** when splitting large strings
3. **Reuse String objects** when processing multiple strings
4. **Use std::string_view** for read-only access when appropriate
5. **Compile with optimizations** (`-O2` or `-O3`)

---

## License

MIT License - See LICENSE file for details.

## Support

- GitHub Issues: https://github.com/carlos-sweb/z-string/issues
- Documentation: https://github.com/carlos-sweb/z-string

---

**Note:** This C++ API provides modern RAII-based wrappers around the Zig implementation, with full ECMAScript 262 String API compatibility and idiomatic C++ patterns.
