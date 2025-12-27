/**
 * z-string - ECMAScript String API for C++
 *
 * A complete implementation of the ECMAScript 262 String API in Zig,
 * exposed to C++ through a modern RAII-based interface.
 *
 * Copyright (c) 2025
 * License: MIT
 */

#ifndef ZSTRING_HPP
#define ZSTRING_HPP

#include "zstring.h"
#include <string>
#include <vector>
#include <optional>
#include <stdexcept>
#include <memory>
#include <cstdint>

namespace zstring {

/**
 * Exception thrown when a ZString operation fails
 */
class Exception : public std::runtime_error {
public:
    explicit Exception(ZStringError error_code, const std::string& message)
        : std::runtime_error(message), error_code_(error_code) {}

    ZStringError error_code() const noexcept { return error_code_; }

private:
    ZStringError error_code_;
};

/**
 * RAII wrapper for C ZString
 *
 * Provides automatic memory management and a modern C++ interface
 * for the ECMAScript String API.
 *
 * Example:
 *   zstring::String str("Hello, World!");
 *   auto upper = str.toUpperCase();
 *   std::cout << upper << std::endl; // "HELLO, WORLD!"
 */
class String {
public:
    /**
     * Construct from C++ string
     */
    explicit String(const std::string& str) {
        ZStringError err = zstring_init(str.c_str(), &handle_);
        if (err != ZSTRING_OK) {
            throw Exception(err, "Failed to initialize ZString");
        }
    }

    /**
     * Construct from C string
     */
    explicit String(const char* str) {
        if (!str) {
            throw Exception(ZSTRING_ERROR_INVALID_ARGUMENT, "Null string pointer");
        }
        ZStringError err = zstring_init(str, &handle_);
        if (err != ZSTRING_OK) {
            throw Exception(err, "Failed to initialize ZString");
        }
    }

    /**
     * Move constructor
     */
    String(String&& other) noexcept : handle_(other.handle_) {
        other.handle_ = nullptr;
    }

    /**
     * Move assignment
     */
    String& operator=(String&& other) noexcept {
        if (this != &other) {
            if (handle_) {
                zstring_free(handle_);
            }
            handle_ = other.handle_;
            other.handle_ = nullptr;
        }
        return *this;
    }

    /**
     * Destructor - automatically frees memory
     */
    ~String() {
        if (handle_) {
            zstring_free(handle_);
        }
    }

    // Delete copy constructor and copy assignment
    String(const String&) = delete;
    String& operator=(const String&) = delete;

    /* ========================================================================
     * Properties
     * ====================================================================== */

    /**
     * Get length in UTF-16 code units (like JavaScript .length)
     */
    size_t length() const {
        return zstring_length(handle_);
    }

    /**
     * Convert to std::string
     */
    std::string toString() const {
        return std::string(zstring_bytes(handle_));
    }

    /**
     * Implicit conversion to std::string
     */
    operator std::string() const {
        return toString();
    }

    /* ========================================================================
     * Character Access
     * ====================================================================== */

    /**
     * Get character at index (String.prototype.charAt)
     *
     * @throws Exception on error
     */
    std::string charAt(size_t index) const {
        char* result = nullptr;
        ZStringError err = zstring_char_at(handle_, index, &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "charAt failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /**
     * Get character at index with negative indexing (String.prototype.at)
     *
     * @return std::nullopt if index out of bounds
     * @throws Exception on error
     */
    std::optional<std::string> at(int64_t index) const {
        char* result = nullptr;
        ZStringError err = zstring_at(handle_, index, &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "at failed");
        }
        if (!result) {
            return std::nullopt;
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /**
     * Get UTF-16 code unit at index (String.prototype.charCodeAt)
     *
     * @throws Exception on error
     */
    uint16_t charCodeAt(size_t index) const {
        uint16_t code_unit;
        ZStringError err = zstring_char_code_at(handle_, index, &code_unit);
        if (err != ZSTRING_OK) {
            throw Exception(err, "charCodeAt failed");
        }
        return code_unit;
    }

    /**
     * Get Unicode code point at index (String.prototype.codePointAt)
     *
     * @throws Exception on error
     */
    uint32_t codePointAt(size_t index) const {
        uint32_t code_point;
        ZStringError err = zstring_code_point_at(handle_, index, &code_point);
        if (err != ZSTRING_OK) {
            throw Exception(err, "codePointAt failed");
        }
        return code_point;
    }

    /* ========================================================================
     * Search Methods
     * ====================================================================== */

    /**
     * Find first occurrence of substring (String.prototype.indexOf)
     *
     * @return Index of first occurrence, or -1 if not found
     */
    int64_t indexOf(const std::string& search_str, int64_t position = 0) const {
        return zstring_index_of(handle_, search_str.c_str(), position);
    }

    /**
     * Find last occurrence of substring (String.prototype.lastIndexOf)
     *
     * @return Index of last occurrence, or -1 if not found
     */
    int64_t lastIndexOf(const std::string& search_str, int64_t position = -1) const {
        return zstring_last_index_of(handle_, search_str.c_str(), position);
    }

    /**
     * Check if string contains substring (String.prototype.includes)
     */
    bool includes(const std::string& search_str, int64_t position = 0) const {
        return zstring_includes(handle_, search_str.c_str(), position);
    }

    /**
     * Check if string starts with substring (String.prototype.startsWith)
     */
    bool startsWith(const std::string& search_str, int64_t position = 0) const {
        return zstring_starts_with(handle_, search_str.c_str(), position);
    }

    /**
     * Check if string ends with substring (String.prototype.endsWith)
     */
    bool endsWith(const std::string& search_str, int64_t length = -1) const {
        return zstring_ends_with(handle_, search_str.c_str(), length);
    }

    /* ========================================================================
     * Transform Methods
     * ====================================================================== */

    /**
     * Extract substring (String.prototype.slice)
     *
     * @throws Exception on error
     */
    std::string slice(int64_t start, int64_t end = INT64_MAX) const {
        char* result = nullptr;
        ZStringError err = zstring_slice(handle_, start, end, &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "slice failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /**
     * Extract substring (String.prototype.substring)
     *
     * @throws Exception on error
     */
    std::string substring(size_t start, size_t end = SIZE_MAX) const {
        char* result = nullptr;
        ZStringError err = zstring_substring(handle_, start, end, &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "substring failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /**
     * Concatenate strings (String.prototype.concat)
     *
     * @throws Exception on error
     */
    std::string concat(const std::vector<std::string>& strings) const {
        std::vector<const char*> c_strings;
        c_strings.reserve(strings.size());
        for (const auto& s : strings) {
            c_strings.push_back(s.c_str());
        }

        char* result = nullptr;
        ZStringError err = zstring_concat(handle_, c_strings.data(), c_strings.size(), &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "concat failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /**
     * Repeat string N times (String.prototype.repeat)
     *
     * @throws Exception on error
     */
    std::string repeat(size_t count) const {
        char* result = nullptr;
        ZStringError err = zstring_repeat(handle_, count, &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "repeat failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /* ========================================================================
     * Padding Methods
     * ====================================================================== */

    /**
     * Pad string from start (String.prototype.padStart)
     *
     * @throws Exception on error
     */
    std::string padStart(size_t target_length, const std::string& pad_str = " ") const {
        char* result = nullptr;
        ZStringError err = zstring_pad_start(handle_, target_length, pad_str.c_str(), &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "padStart failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /**
     * Pad string from end (String.prototype.padEnd)
     *
     * @throws Exception on error
     */
    std::string padEnd(size_t target_length, const std::string& pad_str = " ") const {
        char* result = nullptr;
        ZStringError err = zstring_pad_end(handle_, target_length, pad_str.c_str(), &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "padEnd failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /* ========================================================================
     * Trimming Methods
     * ====================================================================== */

    /**
     * Remove whitespace from both ends (String.prototype.trim)
     *
     * @throws Exception on error
     */
    std::string trim() const {
        char* result = nullptr;
        ZStringError err = zstring_trim(handle_, &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "trim failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /**
     * Remove whitespace from start (String.prototype.trimStart)
     *
     * @throws Exception on error
     */
    std::string trimStart() const {
        char* result = nullptr;
        ZStringError err = zstring_trim_start(handle_, &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "trimStart failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /**
     * Remove whitespace from end (String.prototype.trimEnd)
     *
     * @throws Exception on error
     */
    std::string trimEnd() const {
        char* result = nullptr;
        ZStringError err = zstring_trim_end(handle_, &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "trimEnd failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /* ========================================================================
     * Split Method
     * ====================================================================== */

    /**
     * Split string into array (String.prototype.split)
     *
     * @throws Exception on error
     */
    std::vector<std::string> split(const std::string& separator, size_t limit = 0) const {
        ZStringArray array;
        ZStringError err = zstring_split(handle_, separator.c_str(), limit, &array);
        if (err != ZSTRING_OK) {
            throw Exception(err, "split failed");
        }

        std::vector<std::string> result;
        result.reserve(array.count);
        for (size_t i = 0; i < array.count; ++i) {
            result.emplace_back(array.items[i]);
        }
        zstring_array_free(&array);
        return result;
    }

    /**
     * Split into characters (String.prototype.split with no separator)
     *
     * @throws Exception on error
     */
    std::vector<std::string> split(size_t limit = 0) const {
        ZStringArray array;
        ZStringError err = zstring_split(handle_, nullptr, limit, &array);
        if (err != ZSTRING_OK) {
            throw Exception(err, "split failed");
        }

        std::vector<std::string> result;
        result.reserve(array.count);
        for (size_t i = 0; i < array.count; ++i) {
            result.emplace_back(array.items[i]);
        }
        zstring_array_free(&array);
        return result;
    }

    /* ========================================================================
     * Case Conversion
     * ====================================================================== */

    /**
     * Convert to lowercase (String.prototype.toLowerCase)
     *
     * @throws Exception on error
     */
    std::string toLowerCase() const {
        char* result = nullptr;
        ZStringError err = zstring_to_lower_case(handle_, &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "toLowerCase failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /**
     * Convert to uppercase (String.prototype.toUpperCase)
     *
     * @throws Exception on error
     */
    std::string toUpperCase() const {
        char* result = nullptr;
        ZStringError err = zstring_to_upper_case(handle_, &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "toUpperCase failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /* ========================================================================
     * Utility Methods
     * ====================================================================== */

    /**
     * Compare strings (String.prototype.localeCompare)
     *
     * @return Negative if this < that, 0 if equal, positive if this > that
     */
    int64_t localeCompare(const std::string& that) const {
        return zstring_locale_compare(handle_, that.c_str());
    }

    /**
     * Unicode normalization (String.prototype.normalize)
     *
     * @param form Normalization form: "NFC", "NFD", "NFKC", "NFKD"
     * @throws Exception on error
     */
    std::string normalize(const std::string& form = "NFC") const {
        char* result = nullptr;
        ZStringError err = zstring_normalize(handle_, form.c_str(), &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "normalize failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /* ========================================================================
     * Regex Methods
     * ====================================================================== */

    /**
     * Search with regex (String.prototype.search)
     *
     * @return Index of match, or -1 if not found
     */
    int64_t search(const std::string& pattern) const {
        return zstring_search(handle_, pattern.c_str());
    }

    /**
     * Match with regex (String.prototype.match)
     *
     * @throws Exception on error
     */
    std::vector<std::string> match(const std::string& pattern) const {
        ZStringArray array;
        ZStringError err = zstring_match(handle_, pattern.c_str(), &array);
        if (err != ZSTRING_OK) {
            throw Exception(err, "match failed");
        }

        std::vector<std::string> result;
        result.reserve(array.count);
        for (size_t i = 0; i < array.count; ++i) {
            result.emplace_back(array.items[i]);
        }
        zstring_array_free(&array);
        return result;
    }

    /**
     * Replace with regex or string (String.prototype.replace)
     *
     * @throws Exception on error
     */
    std::string replace(const std::string& search_value, const std::string& replace_value) const {
        char* result = nullptr;
        ZStringError err = zstring_replace(handle_, search_value.c_str(), replace_value.c_str(), &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "replace failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /**
     * Replace all with regex or string (String.prototype.replaceAll)
     *
     * @throws Exception on error
     */
    std::string replaceAll(const std::string& search_value, const std::string& replace_value) const {
        char* result = nullptr;
        ZStringError err = zstring_replace_all(handle_, search_value.c_str(), replace_value.c_str(), &result);
        if (err != ZSTRING_OK) {
            throw Exception(err, "replaceAll failed");
        }
        std::string str(result);
        zstring_str_free(result);
        return str;
    }

    /* ========================================================================
     * Internal
     * ====================================================================== */

    /**
     * Get the underlying C handle (for advanced use)
     */
    const ZString* handle() const { return handle_; }

private:
    ZString* handle_;
};

} // namespace zstring

#endif /* ZSTRING_HPP */
