/**
 * z-string - ECMAScript String API for C
 *
 * A complete implementation of the ECMAScript 262 String API in Zig,
 * exposed to C through a clean C-compatible interface.
 *
 * Copyright (c) 2025
 * License: MIT
 */

#ifndef ZSTRING_H
#define ZSTRING_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Types and Structures
 * ========================================================================== */

/**
 * Opaque string handle
 */
typedef struct ZString ZString;

/**
 * Error codes
 */
typedef enum {
    ZSTRING_OK = 0,
    ZSTRING_ERROR_OUT_OF_MEMORY = 1,
    ZSTRING_ERROR_INVALID_UTF8 = 2,
    ZSTRING_ERROR_INDEX_OUT_OF_BOUNDS = 3,
    ZSTRING_ERROR_INVALID_ARGUMENT = 4,
    ZSTRING_ERROR_REGEX_COMPILE = 5,
    ZSTRING_ERROR_REGEX_MATCH = 6,
} ZStringError;

/**
 * String array result (for split, match operations)
 */
typedef struct {
    char** items;
    size_t count;
} ZStringArray;

/**
 * Match result for regex operations
 */
typedef struct {
    char* match;
    size_t index;
    char** groups;
    size_t group_count;
} ZStringMatch;

/* ============================================================================
 * Core Functions
 * ========================================================================== */

/**
 * Initialize a new ZString from a UTF-8 C string
 *
 * @param str UTF-8 encoded string (will be copied)
 * @param out Pointer to receive the ZString handle
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_init(const char* str, ZString** out);

/**
 * Free a ZString and all associated memory
 *
 * @param zstr ZString to free
 */
void zstring_free(ZString* zstr);

/**
 * Get the UTF-16 length of the string (like JavaScript .length)
 *
 * @param zstr ZString handle
 * @return Length in UTF-16 code units
 */
size_t zstring_length(const ZString* zstr);

/**
 * Get raw UTF-8 bytes (borrowed, do not free)
 *
 * @param zstr ZString handle
 * @return Pointer to UTF-8 bytes (null-terminated)
 */
const char* zstring_bytes(const ZString* zstr);

/* ============================================================================
 * Character Access
 * ========================================================================== */

/**
 * Get character at index (String.prototype.charAt)
 *
 * @param zstr ZString handle
 * @param index UTF-16 index
 * @param out Pointer to receive allocated character string
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_char_at(const ZString* zstr, size_t index, char** out);

/**
 * Get character at index with negative indexing (String.prototype.at)
 *
 * @param zstr ZString handle
 * @param index UTF-16 index (negative counts from end)
 * @param out Pointer to receive allocated character string (NULL if out of bounds)
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_at(const ZString* zstr, int64_t index, char** out);

/**
 * Get UTF-16 code unit at index (String.prototype.charCodeAt)
 *
 * @param zstr ZString handle
 * @param index UTF-16 index
 * @param out Pointer to receive code unit value
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_char_code_at(const ZString* zstr, size_t index, uint16_t* out);

/**
 * Get Unicode code point at index (String.prototype.codePointAt)
 *
 * @param zstr ZString handle
 * @param index UTF-16 index
 * @param out Pointer to receive code point value
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_code_point_at(const ZString* zstr, size_t index, uint32_t* out);

/* ============================================================================
 * Search Methods
 * ========================================================================== */

/**
 * Find first occurrence of substring (String.prototype.indexOf)
 *
 * @param zstr ZString handle
 * @param search_str Substring to search for
 * @param position Starting position (pass -1 for 0)
 * @return Index of first occurrence, or -1 if not found
 */
int64_t zstring_index_of(const ZString* zstr, const char* search_str, int64_t position);

/**
 * Find last occurrence of substring (String.prototype.lastIndexOf)
 *
 * @param zstr ZString handle
 * @param search_str Substring to search for
 * @param position Starting position (pass -1 for end)
 * @return Index of last occurrence, or -1 if not found
 */
int64_t zstring_last_index_of(const ZString* zstr, const char* search_str, int64_t position);

/**
 * Check if string contains substring (String.prototype.includes)
 *
 * @param zstr ZString handle
 * @param search_str Substring to search for
 * @param position Starting position (pass -1 for 0)
 * @return true if found, false otherwise
 */
bool zstring_includes(const ZString* zstr, const char* search_str, int64_t position);

/**
 * Check if string starts with substring (String.prototype.startsWith)
 *
 * @param zstr ZString handle
 * @param search_str Substring to check
 * @param position Starting position (pass -1 for 0)
 * @return true if starts with substring, false otherwise
 */
bool zstring_starts_with(const ZString* zstr, const char* search_str, int64_t position);

/**
 * Check if string ends with substring (String.prototype.endsWith)
 *
 * @param zstr ZString handle
 * @param search_str Substring to check
 * @param length Length to consider (pass -1 for full length)
 * @return true if ends with substring, false otherwise
 */
bool zstring_ends_with(const ZString* zstr, const char* search_str, int64_t length);

/* ============================================================================
 * Transform Methods
 * ========================================================================== */

/**
 * Extract substring (String.prototype.slice)
 *
 * @param zstr ZString handle
 * @param start Start index (negative counts from end)
 * @param end End index (negative counts from end, pass INT64_MAX for length)
 * @param out Pointer to receive allocated substring
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_slice(const ZString* zstr, int64_t start, int64_t end, char** out);

/**
 * Extract substring (String.prototype.substring)
 *
 * @param zstr ZString handle
 * @param start Start index
 * @param end End index (pass SIZE_MAX for length)
 * @param out Pointer to receive allocated substring
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_substring(const ZString* zstr, size_t start, size_t end, char** out);

/**
 * Concatenate strings (String.prototype.concat)
 *
 * @param zstr ZString handle
 * @param strings Array of strings to concatenate
 * @param count Number of strings in array
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_concat(const ZString* zstr, const char** strings, size_t count, char** out);

/**
 * Repeat string N times (String.prototype.repeat)
 *
 * @param zstr ZString handle
 * @param count Number of repetitions
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_repeat(const ZString* zstr, size_t count, char** out);

/* ============================================================================
 * Padding Methods
 * ========================================================================== */

/**
 * Pad string from start (String.prototype.padStart)
 *
 * @param zstr ZString handle
 * @param target_length Target length in UTF-16 code units
 * @param pad_str Padding string (pass NULL for space)
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_pad_start(const ZString* zstr, size_t target_length, const char* pad_str, char** out);

/**
 * Pad string from end (String.prototype.padEnd)
 *
 * @param zstr ZString handle
 * @param target_length Target length in UTF-16 code units
 * @param pad_str Padding string (pass NULL for space)
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_pad_end(const ZString* zstr, size_t target_length, const char* pad_str, char** out);

/* ============================================================================
 * Trimming Methods
 * ========================================================================== */

/**
 * Remove whitespace from both ends (String.prototype.trim)
 *
 * @param zstr ZString handle
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_trim(const ZString* zstr, char** out);

/**
 * Remove whitespace from start (String.prototype.trimStart)
 *
 * @param zstr ZString handle
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_trim_start(const ZString* zstr, char** out);

/**
 * Remove whitespace from end (String.prototype.trimEnd)
 *
 * @param zstr ZString handle
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_trim_end(const ZString* zstr, char** out);

/* ============================================================================
 * Split Method
 * ========================================================================== */

/**
 * Split string into array (String.prototype.split)
 *
 * @param zstr ZString handle
 * @param separator Separator string (pass NULL to split into characters)
 * @param limit Maximum number of splits (pass 0 for unlimited)
 * @param out Pointer to receive ZStringArray result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_split(const ZString* zstr, const char* separator, size_t limit, ZStringArray* out);

/**
 * Free a ZStringArray returned by zstring_split
 *
 * @param array Array to free
 */
void zstring_array_free(ZStringArray* array);

/* ============================================================================
 * Case Conversion
 * ========================================================================== */

/**
 * Convert to lowercase (String.prototype.toLowerCase)
 *
 * @param zstr ZString handle
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_to_lower_case(const ZString* zstr, char** out);

/**
 * Convert to uppercase (String.prototype.toUpperCase)
 *
 * @param zstr ZString handle
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_to_upper_case(const ZString* zstr, char** out);

/* ============================================================================
 * Utility Methods
 * ========================================================================== */

/**
 * Compare strings (String.prototype.localeCompare)
 *
 * @param zstr ZString handle
 * @param that String to compare with
 * @return Negative if zstr < that, 0 if equal, positive if zstr > that
 */
int64_t zstring_locale_compare(const ZString* zstr, const char* that);

/**
 * Unicode normalization (String.prototype.normalize)
 *
 * @param zstr ZString handle
 * @param form Normalization form: "NFC", "NFD", "NFKC", "NFKD" (pass NULL for "NFC")
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_normalize(const ZString* zstr, const char* form, char** out);

/* ============================================================================
 * Regex Methods
 * ========================================================================== */

/**
 * Search with regex (String.prototype.search)
 *
 * @param zstr ZString handle
 * @param pattern Regex pattern
 * @return Index of match, or -1 if not found
 */
int64_t zstring_search(const ZString* zstr, const char* pattern);

/**
 * Match with regex (String.prototype.match)
 *
 * @param zstr ZString handle
 * @param pattern Regex pattern
 * @param out Pointer to receive ZStringArray result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_match(const ZString* zstr, const char* pattern, ZStringArray* out);

/**
 * Replace with regex or string (String.prototype.replace)
 *
 * @param zstr ZString handle
 * @param search_value Search pattern (regex or string)
 * @param replace_value Replacement string
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_replace(const ZString* zstr, const char* search_value, const char* replace_value, char** out);

/**
 * Replace all with regex or string (String.prototype.replaceAll)
 *
 * @param zstr ZString handle
 * @param search_value Search pattern (regex or string)
 * @param replace_value Replacement string
 * @param out Pointer to receive allocated result
 * @return ZSTRING_OK on success, error code otherwise
 */
ZStringError zstring_replace_all(const ZString* zstr, const char* search_value, const char* replace_value, char** out);

/* ============================================================================
 * Memory Management Helpers
 * ========================================================================== */

/**
 * Free a string allocated by zstring functions
 *
 * @param str String to free
 */
void zstring_str_free(char* str);

#ifdef __cplusplus
}
#endif

#endif /* ZSTRING_H */
