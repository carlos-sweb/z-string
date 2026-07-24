# Phase 3 (locale + full normalization) — complexity analysis

**Status:** documented, not implemented. This is a scoping/estimation
writeup for the three items listed under README's "Phase 3: Advanced
Features" — they are NOT the same size, even though the README lists
them side by side.

## Current state (verified against the code, not assumed)

**Locale-aware case mapping** — `src/methods/case.zig`:
```zig
pub fn toLocaleLowerCase(allocator: Allocator, str: []const u8, _locale: ?[]const u8) ![]u8 {
    // TODO: Implement locale-specific case mapping
    _ = _locale;
    return toLowerCase(allocator, str);
}
```
The `_locale` parameter is discarded; both `toLocaleLowerCase` and
`toLocaleUpperCase` just call the plain, locale-blind case functions.

**`localeCompare`** — `src/methods/utility.zig`:
```zig
pub fn localeCompare(str: []const u8, that: []const u8, _locales: ?[]const u8, _options: ?[]const u8) isize {
    _ = _locales;
    _ = _options;
    // Simple lexicographic comparison
```
Plain byte-wise comparison, same story — `_locales`/`_options` ignored.

**Unicode normalization** — `src/methods/unicode_normalize.zig`, own
comment: *"Common decomposition mappings for Latin-1 Supplement and
Latin Extended"* — covers the 0x00C0-0x00FF range (accented Latin
letters like À-ÿ) and little else. Real NFC/NFD/NFKC/NFKD needs the full
Unicode Character Database's decomposition tables, not just Latin.

## Difficulty, per item (1-10)

These three overlap conceptually (the README groups them as one "Phase
3") but are wildly different in scope. Splitting them out:

### 1. Locale-aware case mapping — **3-4/10**

Bounded problem. Real engines don't reach for full ICU to implement
`toLocaleLowerCase`/`toLocaleUpperCase` either — they apply a small,
fixed table of exceptions from the Unicode Standard's own
`SpecialCasing.txt`, keyed by language tag. The known exceptions are
few:
- Turkish / Azerbaijani (`tr`, `az`): dotless ı/I vs dotted i/İ behave
  differently than the default Latin mapping.
- Lithuanian (`lt`): retains the dot over i/j/į in certain combining
  sequences that would otherwise drop it.

That's a lookup table with on the order of a few dozen entries total,
plus a locale-tag check, plus (for Lithuanian) a context check on
adjacent combining marks. No ICU dependency, no UCD-wide table
generation needed. `localeCompare` staying a plain byte comparison for
non-Latin-adjacent locales is a separate, smaller item in the same
family.

### 2. Extended Unicode normalization (full UCD coverage) — **9/10**

This is the real undertaking. Full NFC/NFD/NFKC/NFKD needs:
- The complete canonical AND compatibility decomposition tables from
  `UnicodeData.txt` — thousands of entries across every script, not
  just Latin.
- The Canonical Combining Class (CCC) for every combining character,
  needed for the canonical ordering step of the algorithm (reordering
  combining marks that don't interact).
- The Composition Exclusion Table, needed so NFC/NFKC don't recompose
  characters the standard says shouldn't be recomposed.
- Hangul syllable decomposition/composition — algorithmic (a formula,
  not a table) but still a separate subsystem to get right.

Unlike `fromCharCode`/`fromCodePoint` (which reused
`std.unicode.utf16LeToUtf8Alloc`/`utf8Encode` for free), Zig's standard
library has no normalization support at all — this would mean
generating real data tables from the actual Unicode Character Database
files, not just writing an algorithm. It's the kind of scope dedicated
libraries (ICU, Rust's `unicode-normalization` crate) treat as its own
maintained subproject, kept in sync with each Unicode version.

### 3. Full locale support ("ICU integration") — **5-6/10 or 10/10, depending which you mean**

The README's phrasing is ambiguous between two very different projects:

- **FFI-bind the real ICU C library.** Zig interops with C reasonably
  well, so this is achievable (~5-6/10) — but it adds a large native,
  non-Zig dependency, with the cross-platform build/link concerns that
  come with it, which cuts against this ecosystem's "pure Zig" approach
  elsewhere.
- **Reimplement locale-aware collation natively.** This is a 10/10 — the
  Unicode Collation Algorithm with per-locale tailoring rules (DUCET +
  CLDR tailoring data) is one of the most intricate corners of the
  entire internationalization space, comparable in scope to writing a
  full regex engine from scratch.

## How these relate to each other

"Locale-aware case mapping" is really a small subset of "full locale
support" — not a separate track. "Extended Unicode normalization" is
the odd one out: NFC/NFD/NFKC/NFKD are **locale-independent** — pure
Unicode operations, unrelated to any of the locale work. The README
groups all three under one "Phase 3" heading without making that
distinction, which makes the section read as one lump of "future work"
when it's actually two unrelated tracks of very different size.

## Suggested priority, if this gets picked up

1. **Locale-aware case mapping** first — cheap, bounded, closes the
   exact Turkish example the README already cites as motivation.
2. **Extended Unicode normalization** — the real investment, worth
   doing if `normalize()` needs to be trustworthy beyond Latin text.
3. **Real ICU/collation** — leave out of scope unless a concrete need
   shows up; it's the single most expensive item in this whole library's
   roadmap.
