# `isWellFormed()` / `toWellFormed()` — known gap, deferred

**Status:** documented, not implemented to spec. Candidate for a future
session — estimated difficulty 8/10 (see below for why it's not a small fix).

## What ECMA-262 expects

A JavaScript string is a sequence of UTF-16 code units with **no validation**
— it can contain a "lone surrogate" (one half of a surrogate pair, without
its partner), which is perfectly legal JS (`String.fromCharCode(0xD800)`
is a valid, length-1 string) but is **not valid Unicode text**.

`isWellFormed()` reports whether a string has any lone surrogates.
`toWellFormed()` returns a copy with each lone surrogate replaced by
U+FFFD (REPLACEMENT CHARACTER), so it's safe to hand to anything that
requires real Unicode/UTF-8.

**Why this matters in practice — URIs and UTF-8 boundaries:**
`encodeURI`/`encodeURIComponent` throw `URIError: URI malformed` on a
string with a lone surrogate, because there's no UTF-8 encoding for it.
`TextEncoder`, `fetch()` bodies, file writes — anything that has to leave
the UTF-16 world and become real UTF-8 bytes — hits the same wall.
`toWellFormed()` is the spec-sanctioned way to sanitize a string before
crossing that boundary without throwing. This was the actual motivation
for the ES2024 "Well-Formed Unicode Strings" proposal.

## What z-string has today

```zig
pub fn isWellFormed(self: ZString) bool {
    return std.unicode.utf8ValidateSlice(self.data);
}
```

This checks a **different** invariant than the spec asks for: "are these
bytes valid standard UTF-8," not "does this string have lone surrogates."
`toWellFormed()` doesn't exist at all.

## Why it's not a small fix

Standard UTF-8 **cannot encode a lone surrogate at all** — the Unicode
standard explicitly excludes the U+D800–U+DFFF range from valid UTF-8;
any conforming decoder rejects those bytes outright. z-string stores
strings as `[]const u8`. If that's standard UTF-8, **it is structurally
impossible for a `ZString` to ever hold the exact data `isWellFormed`/
`toWellFormed` are supposed to detect and fix** — there's no byte
sequence that means "a lone surrogate" in valid UTF-8.

Confirmed while investigating:
- `ZString.init`/`initOwned` don't validate their input at all (any bytes
  are accepted silently) — so nothing stops someone from constructing a
  `ZString` with non-standard bytes.
- But `core/utf16.zig`'s length/indexing math doesn't recognize a
  surrogate-encoding byte sequence specially either — it falls back to a
  generic "invalid byte, count as 1 and skip" path, which would
  **miscount** a real surrogate-carrying sequence (which is 3 bytes in
  WTF-8, not 1) rather than treat it as one correct UTF-16 code unit.

So there's no cheap patch: the representation itself doesn't have room
for the input these two functions are supposed to operate on.

## What a real fix would require

Real engines (V8, SpiderMonkey) solve this internally with **WTF-8** — a
UTF-8-like encoding that deliberately allows encoding a lone surrogate as
a reserved 3-byte sequence, specifically so JS strings round-trip
losslessly through byte storage. Doing this properly in z-string means:

1. Adopting WTF-8 (or a real UTF-16 array) as `ZString`'s actual
   representation contract — not a local patch, a change to what a
   "string" IS at the lowest layer everything else builds on.
2. Auditing and updating `core/utf16.zig`'s length/index/iteration logic
   to recognize the WTF-8 surrogate sequence as exactly one UTF-16 code
   unit, instead of falling through the generic invalid-byte path.
3. Only then do `isWellFormed()`/`toWellFormed()` have real, correct
   data to operate on.

## Current honest behavior (until this is picked up)

`isWellFormed()` will return `true` for any `ZString` built through the
normal, UTF-8-producing construction paths — not because well-formedness
is actually being checked, but because the storage format already can't
hold anything else. This is a real, permanent limitation of the current
architecture, not a temporary gap that'll close itself as more methods
get added.
