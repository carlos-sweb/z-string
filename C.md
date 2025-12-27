# Using z-string from C

This guide explains how to use **z-string** from C programs. z-string provides a complete ECMAScript 262 String API implementation through a clean C-compatible interface.

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
- C compiler (gcc, clang, etc.)

### Building the C Library

```bash
# Clone the repository
git clone https://github.com/carlos-sweb/z-string.git
cd z-string

# Build the static library
zig build-lib src/c_api.zig -target native -O ReleaseFast

# This will create libzstring.a (static) or libzstring.so (dynamic)
```

### Linking in Your Project

**Static linking:**
```bash
gcc your_program.c -I./include -L. -lzstring -o your_program
```

**Dynamic linking:**
```bash
gcc your_program.c -I./include -L. -lzstring -Wl,-rpath,. -o your_program
```

---

## Quick Start

Here's a simple example to get you started:

```c
#include <stdio.h>
#include <stdlib.h>
#include "zstring.h"

int main(void) {
    ZString* str = NULL;
    ZStringError err;

    // Create a new string
    err = zstring_init("Hello, World!", &str);
    if (err != ZSTRING_OK) {
        fprintf(stderr, "Failed to create string\n");
        return 1;
    }

    // Get the length
    size_t len = zstring_length(str);
    printf("Length: %zu\n", len);

    // Convert to uppercase
    char* upper = NULL;
    err = zstring_to_upper_case(str, &upper);
    if (err == ZSTRING_OK) {
        printf("Uppercase: %s\n", upper);
        zstring_str_free(upper);
    }

    // Clean up
    zstring_free(str);
    return 0;
}
```

**Output:**
```
Length: 13
Uppercase: HELLO, WORLD!
```

---

## Memory Management

z-string uses explicit memory management. You are responsible for freeing all allocated resources.

### Rules

1. **Always free ZString handles** with `zstring_free()`
2. **Always free returned strings** with `zstring_str_free()`
3. **Always free arrays** with `zstring_array_free()`
4. **Never free borrowed pointers** from `zstring_bytes()`

### Example

```c
ZString* str = NULL;
zstring_init("example", &str);

// Get a character (allocates memory)
char* ch = NULL;
zstring_char_at(str, 0, &ch);
printf("%s\n", ch);
zstring_str_free(ch);  // ✅ Free allocated string

// Get raw bytes (borrowed, DO NOT free)
const char* bytes = zstring_bytes(str);
printf("%s\n", bytes);  // ✅ Use borrowed pointer
// ❌ DO NOT: zstring_str_free((char*)bytes);

// Clean up the handle
zstring_free(str);  // ✅ Always free the handle
```

---

## Error Handling

All functions that can fail return a `ZStringError` code or use output parameters.

### Error Codes

```c
typedef enum {
    ZSTRING_OK = 0,                    // Success
    ZSTRING_ERROR_OUT_OF_MEMORY = 1,   // Memory allocation failed
    ZSTRING_ERROR_INVALID_UTF8 = 2,    // Invalid UTF-8 input
    ZSTRING_ERROR_INDEX_OUT_OF_BOUNDS = 3,  // Index out of range
    ZSTRING_ERROR_INVALID_ARGUMENT = 4,     // Invalid argument
    ZSTRING_ERROR_REGEX_COMPILE = 5,   // Regex compilation failed
    ZSTRING_ERROR_REGEX_MATCH = 6,     // Regex match failed
} ZStringError;
```

### Checking Errors

```c
ZString* str = NULL;
ZStringError err = zstring_init("test", &str);

if (err != ZSTRING_OK) {
    switch (err) {
        case ZSTRING_ERROR_OUT_OF_MEMORY:
            fprintf(stderr, "Out of memory\n");
            break;
        case ZSTRING_ERROR_INVALID_UTF8:
            fprintf(stderr, "Invalid UTF-8\n");
            break;
        default:
            fprintf(stderr, "Unknown error: %d\n", err);
            break;
    }
    return 1;
}

// Use str...
zstring_free(str);
```

---

## API Reference

### Core Functions

#### `zstring_init`
```c
ZStringError zstring_init(const char* str, ZString** out);
```
Create a new ZString from a UTF-8 C string.

**Example:**
```c
ZString* str = NULL;
ZStringError err = zstring_init("Hello", &str);
if (err == ZSTRING_OK) {
    // Use str...
    zstring_free(str);
}
```

#### `zstring_free`
```c
void zstring_free(ZString* zstr);
```
Free a ZString and all associated memory.

#### `zstring_length`
```c
size_t zstring_length(const ZString* zstr);
```
Get the length in UTF-16 code units (like JavaScript `.length`).

#### `zstring_bytes`
```c
const char* zstring_bytes(const ZString* zstr);
```
Get raw UTF-8 bytes (borrowed, do not free).

---

### Character Access

#### `zstring_char_at`
```c
ZStringError zstring_char_at(const ZString* zstr, size_t index, char** out);
```
Get character at index (String.prototype.charAt).

**Example:**
```c
char* ch = NULL;
if (zstring_char_at(str, 0, &ch) == ZSTRING_OK) {
    printf("First char: %s\n", ch);
    zstring_str_free(ch);
}
```

#### `zstring_at`
```c
ZStringError zstring_at(const ZString* zstr, int64_t index, char** out);
```
Get character with negative indexing support (String.prototype.at).

**Example:**
```c
char* last = NULL;
if (zstring_at(str, -1, &last) == ZSTRING_OK) {
    if (last) {
        printf("Last char: %s\n", last);
        zstring_str_free(last);
    }
}
```

#### `zstring_char_code_at`
```c
ZStringError zstring_char_code_at(const ZString* zstr, size_t index, uint16_t* out);
```
Get UTF-16 code unit at index.

**Example:**
```c
uint16_t code_unit;
if (zstring_char_code_at(str, 0, &code_unit) == ZSTRING_OK) {
    printf("Code unit: 0x%04X\n", code_unit);
}
```

#### `zstring_code_point_at`
```c
ZStringError zstring_code_point_at(const ZString* zstr, size_t index, uint32_t* out);
```
Get Unicode code point at index.

**Example:**
```c
uint32_t code_point;
if (zstring_code_point_at(str, 0, &code_point) == ZSTRING_OK) {
    printf("Code point: U+%04X\n", code_point);
}
```

---

### Search Methods

#### `zstring_index_of`
```c
int64_t zstring_index_of(const ZString* zstr, const char* search_str, int64_t position);
```
Find first occurrence of substring. Returns index or -1 if not found.

**Example:**
```c
int64_t pos = zstring_index_of(str, "World", 0);
if (pos >= 0) {
    printf("Found at: %lld\n", (long long)pos);
}
```

#### `zstring_last_index_of`
```c
int64_t zstring_last_index_of(const ZString* zstr, const char* search_str, int64_t position);
```
Find last occurrence of substring.

#### `zstring_includes`
```c
bool zstring_includes(const ZString* zstr, const char* search_str, int64_t position);
```
Check if string contains substring.

**Example:**
```c
if (zstring_includes(str, "World", 0)) {
    printf("Contains 'World'\n");
}
```

#### `zstring_starts_with`
```c
bool zstring_starts_with(const ZString* zstr, const char* search_str, int64_t position);
```
Check if string starts with substring.

#### `zstring_ends_with`
```c
bool zstring_ends_with(const ZString* zstr, const char* search_str, int64_t length);
```
Check if string ends with substring.

---

### Transform Methods

#### `zstring_slice`
```c
ZStringError zstring_slice(const ZString* zstr, int64_t start, int64_t end, char** out);
```
Extract substring with negative indices support.

**Example:**
```c
char* result = NULL;
if (zstring_slice(str, 0, 5, &result) == ZSTRING_OK) {
    printf("Slice: %s\n", result);
    zstring_str_free(result);
}
```

#### `zstring_substring`
```c
ZStringError zstring_substring(const ZString* zstr, size_t start, size_t end, char** out);
```
Extract substring (swaps if start > end).

#### `zstring_concat`
```c
ZStringError zstring_concat(const ZString* zstr, const char** strings, size_t count, char** out);
```
Concatenate multiple strings.

**Example:**
```c
const char* parts[] = {" ", "World", "!"};
char* result = NULL;
if (zstring_concat(str, parts, 3, &result) == ZSTRING_OK) {
    printf("Concatenated: %s\n", result);
    zstring_str_free(result);
}
```

#### `zstring_repeat`
```c
ZStringError zstring_repeat(const ZString* zstr, size_t count, char** out);
```
Repeat string N times.

**Example:**
```c
char* result = NULL;
if (zstring_repeat(str, 3, &result) == ZSTRING_OK) {
    printf("Repeated: %s\n", result);
    zstring_str_free(result);
}
```

---

### Padding Methods

#### `zstring_pad_start`
```c
ZStringError zstring_pad_start(const ZString* zstr, size_t target_length, const char* pad_str, char** out);
```
Pad string from start.

**Example:**
```c
char* result = NULL;
if (zstring_pad_start(str, 10, "0", &result) == ZSTRING_OK) {
    printf("Padded: %s\n", result);
    zstring_str_free(result);
}
```

#### `zstring_pad_end`
```c
ZStringError zstring_pad_end(const ZString* zstr, size_t target_length, const char* pad_str, char** out);
```
Pad string from end.

---

### Trimming Methods

#### `zstring_trim`
```c
ZStringError zstring_trim(const ZString* zstr, char** out);
```
Remove whitespace from both ends.

**Example:**
```c
char* result = NULL;
if (zstring_trim(str, &result) == ZSTRING_OK) {
    printf("Trimmed: %s\n", result);
    zstring_str_free(result);
}
```

#### `zstring_trim_start`
```c
ZStringError zstring_trim_start(const ZString* zstr, char** out);
```
Remove whitespace from start.

#### `zstring_trim_end`
```c
ZStringError zstring_trim_end(const ZString* zstr, char** out);
```
Remove whitespace from end.

---

### Split Method

#### `zstring_split`
```c
ZStringError zstring_split(const ZString* zstr, const char* separator, size_t limit, ZStringArray* out);
```
Split string into array.

**Example:**
```c
ZStringArray array;
if (zstring_split(str, ",", 0, &array) == ZSTRING_OK) {
    for (size_t i = 0; i < array.count; i++) {
        printf("Part %zu: %s\n", i, array.items[i]);
    }
    zstring_array_free(&array);
}
```

#### `zstring_array_free`
```c
void zstring_array_free(ZStringArray* array);
```
Free a ZStringArray.

---

### Case Conversion

#### `zstring_to_lower_case`
```c
ZStringError zstring_to_lower_case(const ZString* zstr, char** out);
```
Convert to lowercase.

**Example:**
```c
char* result = NULL;
if (zstring_to_lower_case(str, &result) == ZSTRING_OK) {
    printf("Lowercase: %s\n", result);
    zstring_str_free(result);
}
```

#### `zstring_to_upper_case`
```c
ZStringError zstring_to_upper_case(const ZString* zstr, char** out);
```
Convert to uppercase.

---

### Utility Methods

#### `zstring_locale_compare`
```c
int64_t zstring_locale_compare(const ZString* zstr, const char* that);
```
Compare strings. Returns negative if less, 0 if equal, positive if greater.

#### `zstring_normalize`
```c
ZStringError zstring_normalize(const ZString* zstr, const char* form, char** out);
```
Unicode normalization (NFC, NFD, NFKC, NFKD).

**Example:**
```c
char* result = NULL;
if (zstring_normalize(str, "NFC", &result) == ZSTRING_OK) {
    printf("Normalized: %s\n", result);
    zstring_str_free(result);
}
```

---

### Regex Methods

#### `zstring_search`
```c
int64_t zstring_search(const ZString* zstr, const char* pattern);
```
Search with regex. Returns index or -1.

**Example:**
```c
int64_t pos = zstring_search(str, "\\d+");
if (pos >= 0) {
    printf("Match at: %lld\n", (long long)pos);
}
```

#### `zstring_match`
```c
ZStringError zstring_match(const ZString* zstr, const char* pattern, ZStringArray* out);
```
Match with regex.

#### `zstring_replace`
```c
ZStringError zstring_replace(const ZString* zstr, const char* search_value, const char* replace_value, char** out);
```
Replace first match.

#### `zstring_replace_all`
```c
ZStringError zstring_replace_all(const ZString* zstr, const char* search_value, const char* replace_value, char** out);
```
Replace all matches.

---

## Examples

### Complete Example: Text Processing

```c
#include <stdio.h>
#include <stdlib.h>
#include "zstring.h"

int main(void) {
    ZString* str = NULL;
    ZStringError err;

    // Create string
    err = zstring_init("  Hello, World!  ", &str);
    if (err != ZSTRING_OK) {
        fprintf(stderr, "Failed to create string\n");
        return 1;
    }

    // Trim whitespace
    char* trimmed = NULL;
    err = zstring_trim(str, &trimmed);
    if (err == ZSTRING_OK) {
        printf("Trimmed: '%s'\n", trimmed);
        zstring_str_free(trimmed);
    }

    // Convert to uppercase
    char* upper = NULL;
    err = zstring_to_upper_case(str, &upper);
    if (err == ZSTRING_OK) {
        printf("Upper: %s\n", upper);
        zstring_str_free(upper);
    }

    // Split into words
    ZStringArray words;
    err = zstring_split(str, " ", 0, &words);
    if (err == ZSTRING_OK) {
        printf("Word count: %zu\n", words.count);
        for (size_t i = 0; i < words.count; i++) {
            printf("  Word %zu: '%s'\n", i + 1, words.items[i]);
        }
        zstring_array_free(&words);
    }

    // Clean up
    zstring_free(str);
    return 0;
}
```

### Example: Character Analysis

```c
#include <stdio.h>
#include "zstring.h"

int main(void) {
    ZString* str = NULL;
    zstring_init("Hello 😀", &str);

    size_t len = zstring_length(str);
    printf("Length (UTF-16): %zu\n", len);

    // Iterate through characters
    for (size_t i = 0; i < len; i++) {
        char* ch = NULL;
        uint32_t cp;

        if (zstring_char_at(str, i, &ch) == ZSTRING_OK) {
            printf("Index %zu: %s", i, ch);
            zstring_str_free(ch);
        }

        if (zstring_code_point_at(str, i, &cp) == ZSTRING_OK) {
            printf(" (U+%04X)\n", cp);
        }
    }

    zstring_free(str);
    return 0;
}
```

---

## Best Practices

### 1. Always Check Return Values

```c
// ❌ Bad
char* upper;
zstring_to_upper_case(str, &upper);

// ✅ Good
char* upper = NULL;
if (zstring_to_upper_case(str, &upper) == ZSTRING_OK) {
    // Use upper...
    zstring_str_free(upper);
}
```

### 2. Initialize Output Pointers to NULL

```c
// ✅ Good practice
char* result = NULL;
if (zstring_slice(str, 0, 5, &result) == ZSTRING_OK) {
    // Safe to use result
    zstring_str_free(result);
}
```

### 3. Free Resources in Reverse Order

```c
ZString* str1 = NULL;
ZString* str2 = NULL;

zstring_init("first", &str1);
zstring_init("second", &str2);

// Free in reverse order
zstring_free(str2);
zstring_free(str1);
```

### 4. Use const for Read-Only Operations

```c
void print_string(const ZString* str) {
    const char* bytes = zstring_bytes(str);
    printf("%s\n", bytes);
}
```

### 5. Handle Edge Cases

```c
// Check for NULL
if (!str) {
    fprintf(stderr, "NULL string\n");
    return;
}

// Check index bounds
size_t len = zstring_length(str);
if (index >= len) {
    fprintf(stderr, "Index out of bounds\n");
    return;
}
```

---

## Compilation Tips

### Static Linking

```bash
# Compile z-string as static library
zig build-lib src/c_api.zig -O ReleaseFast

# Link with your program
gcc -O2 your_program.c -I./include -L. -lzstring -o your_program
```

### Dynamic Linking

```bash
# Compile z-string as shared library
zig build-lib src/c_api.zig -O ReleaseFast -dynamic

# Link with your program
gcc -O2 your_program.c -I./include -L. -lzstring -Wl,-rpath,. -o your_program
```

### Debug Build

```bash
# Debug build for development
zig build-lib src/c_api.zig -O Debug

gcc -g your_program.c -I./include -L. -lzstring -o your_program
```

---

## Troubleshooting

### Undefined Reference Errors

```bash
# Make sure you're linking the library
gcc your_program.c -I./include -L. -lzstring
```

### Runtime Library Not Found

```bash
# Add library path to LD_LIBRARY_PATH
export LD_LIBRARY_PATH=.:$LD_LIBRARY_PATH
./your_program

# Or use rpath
gcc your_program.c -I./include -L. -lzstring -Wl,-rpath,.
```

### Memory Leaks

Use valgrind to detect memory leaks:

```bash
valgrind --leak-check=full ./your_program
```

Common causes:
- Forgetting to call `zstring_free()`
- Forgetting to call `zstring_str_free()`
- Forgetting to call `zstring_array_free()`

---

## Performance Tips

1. **Reuse ZString handles** instead of creating new ones repeatedly
2. **Use borrowed pointers** (`zstring_bytes()`) when you don't need ownership
3. **Preallocate arrays** when you know the size
4. **Avoid unnecessary conversions** between C strings and ZStrings

---

## License

MIT License - See LICENSE file for details.

## Support

- GitHub Issues: https://github.com/carlos-sweb/z-string/issues
- Documentation: https://github.com/carlos-sweb/z-string

---

**Note:** This is a C API wrapper around the Zig implementation. All functions are fully compatible with ECMAScript 262 String API specification.
