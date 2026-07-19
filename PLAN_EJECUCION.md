# Plan de Ejecución: z-string para Runtime ECMAScript en Zig

## Contexto del Proyecto

**Objetivo Principal**: Implementar la API String de ECMAScript 262 en Zig como parte de un futuro runtime engine ECMA.

**Implicaciones Críticas**:
- ✅ Compatibilidad **EXACTA** con la especificación ECMAScript
- ✅ Manejo de strings como UTF-16 (igual que JS) aunque internamente use UTF-8
- ✅ Comportamiento idéntico en edge cases
- ✅ Índices y length basados en UTF-16 code units (no bytes, no code points)
- ⏳ Integración futura con `libzregex` para métodos regex

**Aprovechar stdlib de Zig**:
- Usar `std.mem` como base cuando sea posible
- Crear wrappers que adapten comportamiento Zig → ECMAScript spec
- No reinventar la rueda, pero garantizar spec compliance

---

## Estructura del Proyecto

```
z-string/
├── build.zig                 # Build configuration
├── build.zig.zon            # Package dependencies
├── src/
│   ├── zstring.zig          # Main module, public API
│   ├── core/
│   │   ├── string.zig       # ZString struct principal
│   │   ├── utf16.zig        # Conversión UTF-8 ↔ UTF-16, indexación
│   │   └── iterator.zig     # Iteradores (Symbol.iterator)
│   ├── methods/
│   │   ├── access.zig       # charAt, at, charCodeAt, codePointAt
│   │   ├── search.zig       # indexOf, lastIndexOf, includes, etc.
│   │   ├── transform.zig    # slice, substring, concat, repeat
│   │   ├── case.zig         # toLowerCase, toUpperCase
│   │   ├── padding.zig      # padStart, padEnd
│   │   ├── trimming.zig     # trim, trimStart, trimEnd
│   │   ├── split.zig        # split (sin regex por ahora)
│   │   └── replace.zig      # replace, replaceAll (sin regex)
│   ├── static/
│   │   └── constructors.zig # fromCharCode, fromCodePoint, raw
│   └── regex/               # Para futuro con libzregex
│       └── stubs.zig        # Stubs que retornan error.NotImplemented
└── tests/
    ├── spec/                # Tests basados en ECMAScript spec
    ├── unit/                # Tests unitarios por método
    ├── utf16/               # Tests específicos de comportamiento UTF-16
    └── benchmarks/          # Performance comparisons

docs/
├── ANALISIS_API.md          # Ya creado
├── PLAN_EJECUCION.md        # Este archivo
└── API_REFERENCE.md         # Documentación de API (crear después)

README.md
LICENSE
.gitignore
```

---

## Fases de Implementación

### FASE 0: Fundamentos (Crítico) 🔴

**Objetivo**: Establecer la base para índices y comportamiento compatible con ECMAScript

#### 0.1 Sistema de Indexación UTF-16
**Problema**: JavaScript usa índices basados en UTF-16 code units, Zig usa UTF-8 bytes.

**Solución**: Crear capa de traducción

```zig
// src/core/utf16.zig

/// Convierte índice UTF-16 a índice de byte UTF-8
pub fn utf16IndexToByte(str: []const u8, utf16_index: usize) !usize;

/// Convierte índice de byte UTF-8 a índice UTF-16
pub fn byteIndexToUtf16(str: []const u8, byte_index: usize) !usize;

/// Retorna la longitud en UTF-16 code units (equivalente a JS .length)
pub fn lengthUtf16(str: []const u8) usize;

/// Retorna el code unit UTF-16 en el índice dado
pub fn codeUnitAt(str: []const u8, utf16_index: usize) !u16;
```

**Tests críticos**:
- ✅ ASCII: "hello".length == 5
- ✅ BMP Unicode: "café".length == 4
- ✅ Emojis (surrogate pairs): "😀".length == 2 (como JS, no 1)
- ✅ Caracteres multi-byte: "你好".length == 2

**Prioridad**: MÁXIMA - Todo depende de esto

---

#### 0.2 Estructura Principal ZString

```zig
// src/core/string.zig

pub const ZString = struct {
    /// Datos UTF-8 internos
    data: []const u8,

    /// Allocator si es owned, null si es slice
    allocator: ?Allocator = null,

    /// Cache de longitud UTF-16 (lazy-computed)
    cached_utf16_length: ?usize = null,

    pub fn init(data: []const u8) ZString {
        return .{ .data = data };
    }

    pub fn initOwned(allocator: Allocator, data: []const u8) !ZString {
        const owned = try allocator.dupe(u8, data);
        return .{
            .data = owned,
            .allocator = allocator
        };
    }

    pub fn deinit(self: *ZString) void {
        if (self.allocator) |alloc| {
            alloc.free(self.data);
        }
    }

    /// Longitud como en JS (UTF-16 code units)
    pub fn length(self: *ZString) usize {
        if (self.cached_utf16_length) |len| return len;
        const len = utf16.lengthUtf16(self.data);
        self.cached_utf16_length = len;
        return len;
    }
};
```

**Decisión de diseño**:
- Struct puede ser "borrowed" (solo slice) o "owned" (con allocator)
- Length siempre retorna UTF-16 code units (spec-compliant)
- Cache de length para evitar recalcular

---

#### 0.3 Configuración de Build

```zig
// build.zig

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zstring = b.addModule("zstring", .{
        .root_source_file = b.path("src/zstring.zig"),
    });

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/zstring.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Benchmarks (opcional)
    const bench = b.addExecutable(.{
        .name = "bench",
        .root_source_file = b.path("tests/benchmarks/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    bench.root_module.addImport("zstring", zstring);

    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);
}
```

---

### FASE 1: Métodos Core (Alta Prioridad) 🟠

**Objetivo**: Implementar métodos más usados, sin dependencia en regex

#### 1.1 Acceso a Caracteres
**Archivos**: `src/methods/access.zig`

Implementar:
- ✅ `charAt(index)` - Retorna string de 1-2 code units
- ✅ `charCodeAt(index)` - Retorna UTF-16 code unit
- ✅ `codePointAt(index)` - Retorna code point completo
- ✅ `at(index)` - Como charAt pero acepta índices negativos

**Consideraciones**:
- Índices en UTF-16 code units (usar utf16.zig)
- charAt con índice fuera de rango → string vacío (no error)
- charCodeAt fuera de rango → NaN (en Zig podría ser null o error, documentar)

**Aprovechar stdlib**:
```zig
// Internamente podemos usar std.unicode.utf8Decode
// pero wrapper para usar índices UTF-16
```

**Tests ECMAScript**:
```javascript
// Estos deben pasar idénticamente en z-string
"hello".charAt(1)        // "e"
"hello".charAt(10)       // ""
"😀".charAt(0)           // "\uD83D" (high surrogate)
"😀".charCodeAt(0)       // 55357
"😀".codePointAt(0)      // 128512
"hello".at(-1)           // "o"
```

---

#### 1.2 Búsqueda (sin regex)
**Archivos**: `src/methods/search.zig`

Implementar:
- ✅ `indexOf(searchString, position?)`
- ✅ `lastIndexOf(searchString, position?)`
- ✅ `includes(searchString, position?)`
- ✅ `startsWith(searchString, position?)`
- ✅ `endsWith(searchString, length?)`

**Aprovechar stdlib**:
```zig
// std.mem.indexOf puede ser la base
// pero necesitamos:
// 1. Convertir position de UTF-16 → bytes
// 2. Retornar índice en UTF-16 code units
// 3. Manejar edge cases exactos de la spec

pub fn indexOf(self: ZString, search: []const u8, position: ?usize) ?usize {
    const pos_bytes = if (position) |p|
        utf16.utf16IndexToByte(self.data, p) catch return null
    else
        0;

    const result_bytes = std.mem.indexOf(u8, self.data[pos_bytes..], search) orelse return null;

    // Convertir resultado a índice UTF-16
    const total_bytes = pos_bytes + result_bytes;
    return utf16.byteIndexToUtf16(self.data, total_bytes) catch null;
}
```

**Tests spec**:
```javascript
"hello world".indexOf("o")          // 4
"hello world".indexOf("o", 5)       // 7
"hello world".indexOf("x")          // -1 (en Zig: null)
"café".indexOf("é")                 // 3
"😀😃".indexOf("😃")                // 2 (no 1!)
```

---

#### 1.3 Transformación Básica
**Archivos**: `src/methods/transform.zig`

Implementar:
- ✅ `concat(...strings)` - Necesita allocator
- ✅ `slice(start, end?)` - Puede retornar slice o owned
- ✅ `substring(start, end?)` - Comportamiento diferente a slice
- ✅ `repeat(count)` - Necesita allocator

**Diferencias críticas slice vs substring**:
```javascript
// slice: índices negativos son relativos al final
"hello".slice(-2)        // "lo"
"hello".slice(3, 1)      // "" (start > end)

// substring: intercambia índices si start > end, no acepta negativos
"hello".substring(3, 1)  // "el" (intercambia a 1, 3)
"hello".substring(-2)    // "hello" (negativo = 0)
```

**Implementación**:
```zig
pub fn slice(self: ZString, allocator: Allocator, start: isize, end: ?isize) ![]u8 {
    const len = self.length();

    // Normalizar índices según spec
    var real_start: usize = if (start < 0)
        @max(0, @as(isize, @intCast(len)) + start)
    else
        @min(start, len);

    var real_end: usize = if (end) |e| blk: {
        if (e < 0) break :blk @max(0, @as(isize, @intCast(len)) + e)
        else break :blk @min(e, len);
    } else len;

    if (real_start >= real_end) return allocator.alloc(u8, 0);

    // Convertir índices UTF-16 → bytes
    const start_byte = try utf16.utf16IndexToByte(self.data, real_start);
    const end_byte = try utf16.utf16IndexToByte(self.data, real_end);

    return allocator.dupe(u8, self.data[start_byte..end_byte]);
}
```

---

#### 1.4 Padding
**Archivos**: `src/methods/padding.zig`

Implementar:
- ✅ `padStart(targetLength, padString?)`
- ✅ `padEnd(targetLength, padString?)`

**Default pad**: espacio " " (U+0020)

**Comportamiento**:
```javascript
"5".padStart(3, "0")      // "005"
"abc".padStart(10)        // "       abc"
"abc".padStart(6, "123")  // "123abc"
"abc".padStart(8, "0")    // "00000abc"
"abc".padStart(1)         // "abc" (no cambia)
```

**Consideración**:
- targetLength es en UTF-16 code units
- Si padString tiene emojis, se complica

---

#### 1.5 Trimming
**Archivos**: `src/methods/trimming.zig`

Implementar:
- ✅ `trim()`
- ✅ `trimStart()` / `trimLeft()`
- ✅ `trimEnd()` / `trimRight()`

**Whitespace según spec ECMAScript**:
- U+0009 (TAB)
- U+000B (VT)
- U+000C (FF)
- U+0020 (SPACE)
- U+00A0 (NBSP)
- U+FEFF (BOM)
- Categoría Unicode Zs (Space Separator)
- Line terminators: LF, CR, LS, PS

**Aprovechar stdlib**:
```zig
// std.mem.trim existe pero puede no incluir todos los whitespace Unicode
// Crear nuestra versión spec-compliant

const whitespace = [_]u21{
    0x0009, 0x000B, 0x000C, 0x0020, 0x00A0, 0xFEFF,
    0x000A, 0x000D, 0x2028, 0x2029,
    // ... otros Zs category
};

pub fn isWhitespace(codepoint: u21) bool {
    // Verificar contra lista de whitespace
}
```

---

#### 1.6 Split (sin regex)
**Archivos**: `src/methods/split.zig`

Implementar:
- ✅ `split(separator?, limit?)`

**Casos especiales**:
```javascript
"a,b,c".split(",")           // ["a", "b", "c"]
"a,b,c".split(",", 2)        // ["a", "b"]
"hello".split("")            // ["h", "e", "l", "l", "o"]
"hello".split()              // ["hello"]
"hello".split(undefined)     // ["hello"]
```

**Retorna**: ArrayList o slice de strings owned

---

#### 1.7 Replace (sin regex)
**Archivos**: `src/methods/replace.zig`

Implementar:
- ✅ `replace(searchValue, replaceValue)` - Solo primera ocurrencia
- ✅ `replaceAll(searchValue, replaceValue)` - Todas las ocurrencias

**Solo strings literales por ahora**:
```javascript
"hello".replace("l", "x")      // "hexlo"
"hello".replaceAll("l", "x")   // "hexxo"
```

**Aprovechar stdlib**:
```zig
// std.mem.replace puede ser útil
// pero necesitamos allocator y spec compliance
```

---

### FASE 2: Case Conversion y Unicode (Media Prioridad) 🟡

**Objetivo**: Conversión de caso correcta para Unicode

#### 2.1 Case Conversion
**Archivos**: `src/methods/case.zig`

Implementar:
- ⚠️ `toLowerCase()` - Unicode completo
- ⚠️ `toUpperCase()` - Unicode completo

**Enfoque**:
1. **Fase 2.1a**: Implementar ASCII simple primero
2. **Fase 2.1b**: Agregar mapeo Unicode completo

**Fuente de datos**: Unicode Case Mapping tables
- ftp://ftp.unicode.org/Public/UNIDATA/UnicodeData.txt
- ftp://ftp.unicode.org/Public/UNIDATA/SpecialCasing.txt

**Casos especiales críticos**:
```javascript
// Sigma final en griego
"ΣΧΟΛΗ".toLowerCase()  // "σχολη" (σ al final)

// Alemán
"Straße".toUpperCase() // "STRASSE"

// Turco (NO implementar aún, es locale-specific)
// "i".toUpperCase() en turco → "İ"
```

**Aprovechar stdlib**:
```zig
// std.ascii.toLower/toUpper para ASCII
// Crear tablas para Unicode BMP (Basic Multilingual Plane)
// Full Unicode puede ser Fase 2.1b
```

---

#### 2.2 Unicode Validation
**Archivos**: `src/methods/validation.zig`

Implementar:
- ✅ `isWellFormed()` - Verifica UTF-8 válido
- ✅ `toWellFormed()` - Reemplaza inválidos con U+FFFD

**En contexto UTF-8**:
```zig
pub fn isWellFormed(self: ZString) bool {
    return std.unicode.utf8ValidateSlice(self.data);
}

pub fn toWellFormed(self: ZString, allocator: Allocator) ![]u8 {
    // Iterar, reemplazar bytes inválidos con U+FFFD (�)
}
```

---

#### 2.3 Normalize
**Archivos**: `src/methods/normalize.zig`

Implementar:
- ⚠️ `normalize(form?)` - NFC, NFD, NFKC, NFKD

**Formas**:
- NFC: Canonical Composition (default)
- NFD: Canonical Decomposition
- NFKC: Compatibility Composition
- NFKD: Compatibility Decomposition

**Ejemplo**:
```javascript
// é puede ser:
// 1. U+00E9 (precomposed)
// 2. U+0065 U+0301 (e + combining acute)

"\u00E9".normalize("NFC")  // "\u00E9"
"\u00E9".normalize("NFD")  // "\u0065\u0301"
```

**Fuente**: Unicode Normalization Tables
- Puede requerir biblioteca externa o generar tablas

---

### FASE 3: Regex Integration (Futura) 🟢

**Objetivo**: Integrar con `libzregex` cuando esté disponible

#### 3.1 Preparación de Stubs
**Archivos**: `src/regex/stubs.zig`

```zig
pub const RegexError = error{
    NotImplemented,
    RegexEngineNotAvailable,
};

pub fn match(self: ZString, pattern: anytype) RegexError!?[]const []const u8 {
    return error.NotImplemented;
}

pub fn matchAll(self: ZString, pattern: anytype) RegexError!Iterator {
    return error.NotImplemented;
}

pub fn search(self: ZString, pattern: anytype) RegexError!?usize {
    return error.NotImplemented;
}

// Versión regex de replace
pub fn replaceRegex(self: ZString, allocator: Allocator, pattern: anytype, replacement: []const u8) RegexError![]u8 {
    return error.NotImplemented;
}
```

**Documentación**:
```zig
/// match() - Pattern matching with regular expressions
///
/// NOTE: This method requires the `libzregex` engine which is not yet integrated.
/// Current status: Returns error.NotImplemented
///
/// Planned support when libzregex is available:
/// - Full ECMAScript regex syntax
/// - Capture groups
/// - Named groups
/// - Flags: g, i, m, s, u, y
```

---

#### 3.2 Diseño de Integración Futura

**API planificada**:
```zig
// Cuando libzregex esté disponible:
const zregex = @import("libzregex");

pub fn match(self: ZString, allocator: Allocator, pattern: []const u8, flags: ?[]const u8) !?MatchResult {
    const regex = try zregex.compile(pattern, flags orelse "");
    return regex.match(self.data);
}
```

**Preparar interface**:
```zig
// src/regex/interface.zig
pub const RegexEngine = struct {
    compile: *const fn(pattern: []const u8, flags: []const u8) RegexError!Regex,
};

pub const Regex = struct {
    match: *const fn(input: []const u8) RegexError!?MatchResult,
    // ...
};

// Permitir inyectar engine
var regex_engine: ?RegexEngine = null;

pub fn setRegexEngine(engine: RegexEngine) void {
    regex_engine = engine;
}
```

---

### FASE 4: Static Methods y Extras 🔵

#### 4.1 Static Constructors
**Archivos**: `src/static/constructors.zig`

Implementar:
- ✅ `fromCharCode(...codes)` - Crear string desde UTF-16 code units
- ✅ `fromCodePoint(...codepoints)` - Crear desde code points
- ⚠️ `raw(template, ...substitutions)` - Para template literals

**fromCharCode**:
```javascript
String.fromCharCode(65, 66, 67)        // "ABC"
String.fromCharCode(0xD83D, 0xDE00)    // "😀" (surrogate pair)
```

**Implementación**:
```zig
pub fn fromCharCode(allocator: Allocator, codes: []const u16) ![]u8 {
    // Convertir array de UTF-16 code units a UTF-8
    // Manejar surrogate pairs correctamente
}

pub fn fromCodePoint(allocator: Allocator, codepoints: []const u21) ![]u8 {
    // Convertir code points a UTF-8
    // Validar que sean code points válidos (0 a 0x10FFFF)
}
```

---

#### 4.2 Iterator
**Archivos**: `src/core/iterator.zig`

Implementar Symbol.iterator equivalente:

```zig
pub const Iterator = struct {
    string: []const u8,
    byte_index: usize = 0,

    /// Retorna el siguiente code point como string
    pub fn next(self: *Iterator) ?[]const u8 {
        if (self.byte_index >= self.string.len) return null;

        const cp_len = std.unicode.utf8ByteSequenceLength(
            self.string[self.byte_index]
        ) catch return null;

        const start = self.byte_index;
        self.byte_index += cp_len;

        return self.string[start..self.byte_index];
    }
};

// Uso:
// var iter = zstr.iterator();
// while (iter.next()) |char| {
//     std.debug.print("{s}\n", .{char});
// }
```

---

### FASE 5: Testing Exhaustivo 🧪

#### 5.1 Test Suite ECMAScript
**Archivos**: `tests/spec/`

Crear tests basados directamente en la spec:

```zig
// tests/spec/charAt_spec.zig
const testing = @import("std").testing;
const ZString = @import("zstring").ZString;

test "charAt - spec compliance" {
    // 22.1.3.1 String.prototype.charAt (pos)

    var s = ZString.init("hello");

    // Step 1: Let O be ? RequireObjectCoercible(this value)
    // (N/A en Zig, siempre válido)

    // Step 2: Let S be ? ToString(O)
    // (Ya es string)

    // Step 3: Let position be ? ToIntegerOrInfinity(pos)
    // Testing con diferentes posiciones
    try testing.expectEqualStrings("h", try s.charAt(testing.allocator, 0));
    try testing.expectEqualStrings("e", try s.charAt(testing.allocator, 1));
    try testing.expectEqualStrings("", try s.charAt(testing.allocator, 10));

    // Surrogate pairs
    var emoji = ZString.init("😀");
    // En UTF-16, emoji es 2 code units
    try testing.expectEqualStrings("\u{D83D}", try emoji.charAt(testing.allocator, 0));
}
```

**Test cases por método**:
- Casos normales
- Edge cases (empty string, fuera de rango, etc.)
- Unicode (BMP, Astral Plane, emojis)
- Surrogate pairs comportamiento
- Todos los ejemplos de la spec

---

#### 5.2 Test de Memoria
**Archivos**: `tests/unit/memory_test.zig`

```zig
test "no memory leaks" {
    const allocator = std.testing.allocator;

    var s = try ZString.initOwned(allocator, "hello");
    defer s.deinit();

    const upper = try s.toUpperCase(allocator);
    defer allocator.free(upper);

    // Si hay leak, testing.allocator lo detectará
}
```

---

#### 5.3 Benchmarks
**Archivos**: `tests/benchmarks/`

Comparar performance:
- z-string vs operaciones nativas Zig
- Diferentes optimizaciones

```zig
pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    // Benchmark indexOf
    var timer = try std.time.Timer.start();

    const haystack = "hello world hello world hello world";
    const needle = "world";

    var i: usize = 0;
    while (i < 1_000_000) : (i += 1) {
        _ = std.mem.indexOf(u8, haystack, needle);
    }

    const elapsed = timer.read();
    try stdout.print("indexOf: {} ns/op\n", .{elapsed / 1_000_000});
}
```

---

## Roadmap Temporal

### Milestone 1: Fundamentos (Semana 1-2)
- [ ] FASE 0 completa: UTF-16 indexing system
- [ ] Estructura ZString básica
- [ ] Build system configurado
- [ ] Primeros tests funcionando

### Milestone 2: Core API (Semana 3-4)
- [ ] FASE 1.1: Acceso a caracteres
- [ ] FASE 1.2: Búsqueda
- [ ] FASE 1.3: Transformación básica
- [ ] Test suite spec para métodos implementados

### Milestone 3: Completar Core (Semana 5-6)
- [ ] FASE 1.4: Padding
- [ ] FASE 1.5: Trimming
- [ ] FASE 1.6: Split
- [ ] FASE 1.7: Replace
- [ ] FASE 4.2: Iterator

### Milestone 4: Unicode (Semana 7-8)
- [ ] FASE 2.1: Case conversion (ASCII)
- [ ] FASE 2.2: Validation
- [ ] FASE 4.1: Static constructors
- [ ] Documentación completa

### Milestone 5: Unicode Full (Semana 9-10)
- [ ] FASE 2.1b: Case conversion Unicode completo
- [ ] FASE 2.3: Normalize (si factible)
- [ ] Tests exhaustivos Unicode
- [ ] Performance optimization

### Milestone 6: Preparación Regex (Futuro)
- [ ] FASE 3.1: Stubs y documentación
- [ ] FASE 3.2: Interface diseñada
- [ ] Integración con libzregex (cuando disponible)

---

## Decisiones Técnicas Finales

### 1. API Pública

```zig
// src/zstring.zig (punto de entrada)

pub const ZString = @import("core/string.zig").ZString;

// Métodos de instancia (via struct)
// zstr.charAt(allocator, 0)
// zstr.slice(allocator, 1, 5)

// Funciones libres (alternativa)
pub const charAt = @import("methods/access.zig").charAt;
pub const slice = @import("methods/transform.zig").slice;

// Static methods
pub const fromCharCode = @import("static/constructors.zig").fromCharCode;
pub const fromCodePoint = @import("static/constructors.zig").fromCodePoint;

// Utilities
pub const utf16 = @import("core/utf16.zig");
```

### 2. Manejo de Allocators

**Regla general**:
- Métodos que solo leen: no necesitan allocator
- Métodos que crean nueva string: primer parámetro es allocator
- Retornar `![]u8` o `![]const u8` según si es owned

```zig
// Lee, no aloca
pub fn indexOf(self: ZString, needle: []const u8) ?usize;

// Crea nueva string, necesita allocator
pub fn toUpperCase(self: ZString, allocator: Allocator) ![]u8;

// Opcionalmente: versiones "Owned" explícitas
pub fn sliceOwned(self: ZString, allocator: Allocator, start: isize, end: isize) ![]u8;
pub fn sliceBorrowed(self: ZString, start: usize, end: usize) []const u8;
```

### 3. Error Handling

```zig
pub const ZStringError = error{
    InvalidUtf8,
    InvalidUtf16,
    IndexOutOfBounds,
    InvalidCodePoint,
    AllocationFailed,
    NotImplemented, // Para métodos regex pendientes
};
```

**Comportamiento**:
- Operaciones inválidas según spec → retornar valor por defecto (empty string, null, etc.)
- Errores de memoria → retornar error
- Métodos no implementados → error.NotImplemented

### 4. Compatibilidad Exacta

**Recursos de referencia**:
- ECMAScript 2025 Spec: https://tc39.es/ecma262/2025/
- Cada método debe referenciar la sección de spec correspondiente

**Ejemplo**:
```zig
/// String.prototype.indexOf (searchString [ , position ] )
/// Spec: https://tc39.es/ecma262/2025/#sec-string.prototype.indexof
///
/// Returns the index of the first occurrence of searchString within this string,
/// starting at position (default 0). Returns -1 if not found.
///
/// NOTE: Indices are in UTF-16 code units as per ECMAScript specification.
pub fn indexOf(self: ZString, search: []const u8, position: ?usize) ?usize {
    // Implementación siguiendo spec exactamente
}
```

---

## Criterios de Éxito

### Para Milestone 2 (MVP)
- ✅ 15+ métodos core funcionando
- ✅ Indexación UTF-16 correcta
- ✅ Tests spec pasando al 100%
- ✅ Cero memory leaks
- ✅ Documentación básica

### Para Milestone 5 (Feature Complete - sin regex)
- ✅ 30+ métodos implementados
- ✅ Unicode completo (case, normalize)
- ✅ 500+ tests pasando
- ✅ Benchmarks documentados
- ✅ Ejemplos de uso
- ✅ Lista para integrar en runtime

### Para Milestone 6 (Full Compliance)
- ✅ Regex integration con libzregex
- ✅ Todos los métodos ECMAScript
- ✅ Test262 compatibility (si aplicable)
- ✅ Production-ready

---

## Próximos Pasos Inmediatos

1. ✅ Crear estructura de carpetas
2. ✅ Implementar `src/core/utf16.zig` (sistema de indexación)
3. ✅ Crear `src/core/string.zig` (ZString struct)
4. ✅ Setup `build.zig`
5. ✅ Primer test: `"hello".length == 5`
6. ✅ Primer método: `charAt()`

¿Listo para comenzar con FASE 0?
