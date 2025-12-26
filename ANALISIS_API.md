# Análisis de Viabilidad: API String de ECMAScript 262 en Zig

## Consideraciones Generales

### Diferencias Fundamentales JavaScript vs Zig
- **JavaScript**: Strings son inmutables, codificación UTF-16
- **Zig**: Strings típicamente []const u8 (UTF-8), memoria explícita
- **Implicación**: Necesitaremos manejar conversiones Unicode y gestión de memoria

### Categorías de Viabilidad
- ✅ **ALTA**: Implementación directa en Zig
- ⚠️ **MEDIA**: Requiere trabajo adicional (Unicode, regex, locale)
- ❌ **BAJA**: Muy complejo o no aplicable en Zig
- 🗑️ **DEPRECATED**: No implementar (obsoleto en JS)

---

## 1. MÉTODOS ESTÁTICOS

### ✅ String.fromCharCode()
**Viabilidad: ALTA**
- Crear string desde valores Unicode
- Zig tiene buen soporte para code points
- **Consideración**: JS usa UTF-16, Zig UTF-8
- **Plan**: Convertir code points a UTF-8

### ✅ String.fromCodePoint()
**Viabilidad: ALTA**
- Similar a fromCharCode pero con code points completos
- Zig maneja code points Unicode naturalmente
- **Plan**: Usar std.unicode para conversión

### ⚠️ String.raw()
**Viabilidad: MEDIA**
- Funciona con template literals (concepto JS)
- **Consideración**: Zig no tiene template literals
- **Plan**: Podría implementarse como función que procesa strings sin escapes

---

## 2. PROPIEDADES DE INSTANCIA

### ✅ length
**Viabilidad: ALTA**
- **Consideración CRÍTICA**: En JS es cantidad de UTF-16 code units
- En Zig necesitamos decidir:
  - `byteLength`: Bytes totales (más eficiente)
  - `codePointLength`: Code points Unicode (más compatible con JS)
- **Plan**: Implementar ambas variantes, documentar diferencia

### ✅ constructor
**Viabilidad: BAJA (no aplicable)**
- Concepto específico de OOP de JavaScript
- En Zig usaríamos funciones init() directamente

---

## 3. MÉTODOS DE INSTANCIA

### 3.1 Acceso a Caracteres

#### ✅ at()
**Viabilidad: ALTA**
- Acceso con índices negativos
- **Plan**: Implementar con índices relativos al final
- Considerar si trabajamos con bytes o code points

#### ✅ charAt()
**Viabilidad: ALTA**
- Retorna carácter en índice específico
- **Plan**: Retornar slice de un code point
- Decidir: ¿retornar []const u8 o copiar a nuevo buffer?

#### ✅ charCodeAt()
**Viabilidad: ALTA**
- Retorna UTF-16 code unit
- **Plan**: En Zig retornar el code point Unicode (u21)
- Documentar que retornamos code point, no UTF-16 unit

#### ✅ codePointAt()
**Viabilidad: ALTA**
- Retorna code point Unicode completo
- **Plan**: Usar std.unicode.utf8Decode
- Esta es la versión más natural en Zig

---

### 3.2 Búsqueda y Coincidencia

#### ✅ indexOf()
**Viabilidad: ALTA**
- Buscar substring, retornar índice
- **Plan**: Implementar búsqueda simple, luego optimizar con algoritmos como KMP o Boyer-Moore
- Decidir: índice en bytes o code points

#### ✅ lastIndexOf()
**Viabilidad: ALTA**
- Búsqueda desde el final
- **Plan**: Similar a indexOf pero iterando desde atrás

#### ✅ includes()
**Viabilidad: ALTA**
- Verificar si contiene substring
- **Plan**: Wrapper sobre indexOf() != -1
- Muy directo

#### ✅ startsWith()
**Viabilidad: ALTA**
- Verificar prefijo
- **Plan**: Comparación simple de slice inicial
- std.mem.startsWith podría ayudar

#### ✅ endsWith()
**Viabilidad: ALTA**
- Verificar sufijo
- **Plan**: Comparación de slice final
- std.mem.endsWith

#### ⚠️ match()
**Viabilidad: MEDIA-BAJA**
- Requiere motor de regex
- **Opciones**:
  - Integrar biblioteca regex externa
  - Implementar subset simple de regex
  - Marcar como "not implemented" inicialmente
- **Decisión**: Fase 2, requiere investigación

#### ⚠️ matchAll()
**Viabilidad: MEDIA-BAJA**
- Como match() pero retorna iterador de todos los matches
- Mismos problemas que match()
- **Plan**: Fase 2

#### ⚠️ search()
**Viabilidad: MEDIA-BAJA**
- Búsqueda con regex
- Misma dependencia de regex que match()
- **Plan**: Fase 2

---

### 3.3 Manipulación de Strings

#### ✅ concat()
**Viabilidad: ALTA**
- Concatenar strings
- **Plan**: Allocar nuevo buffer, copiar contenidos
- Necesita allocator explícito
- **API**: `concat(allocator, ...strings) ![]u8`

#### ✅ slice()
**Viabilidad: ALTA**
- Extraer substring
- **Plan**: Retornar slice o copiar según parámetro
- Manejar índices negativos como JS
- Muy natural en Zig

#### ✅ substring()
**Viabilidad: ALTA**
- Similar a slice con comportamiento diferente para índices
- **Plan**: Implementar lógica específica de substring
- Swap de índices si start > end

#### 🗑️ substr()
**Viabilidad: N/A - DEPRECATED**
- No implementar, está deprecado en JS
- Usar slice() o substring()

#### ⚠️ split()
**Viabilidad: MEDIA**
- Separar string en array
- **Consideraciones**:
  - Sin regex: ALTA viabilidad (usar delimitador string)
  - Con regex: MEDIA-BAJA viabilidad
- **Plan Fase 1**: Implementar con delimitador string simple
- **Plan Fase 2**: Agregar soporte regex

#### ⚠️ replace()
**Viabilidad: MEDIA**
- Reemplazar primera ocurrencia
- **Sin regex**: ALTA - búsqueda simple y reemplazo
- **Con regex**: MEDIA-BAJA
- **Plan Fase 1**: Solo strings literales
- Necesita allocator para nuevo string

#### ⚠️ replaceAll()
**Viabilidad: MEDIA**
- Reemplazar todas las ocurrencias
- Similar a replace()
- **Plan Fase 1**: Versión con strings literales
- Más útil que replace() sin regex

#### ✅ repeat()
**Viabilidad: ALTA**
- Repetir string N veces
- **Plan**: Allocar buffer de size * count, copiar en loop
- Optimización: usar memcpy en chunks

---

### 3.4 Conversión de Caso

#### ⚠️ toLowerCase()
**Viabilidad: MEDIA**
- Conversión a minúsculas
- **Problema**: Conversión Unicode correcta es compleja
  - ASCII: ALTA viabilidad
  - Unicode completo: Requiere tablas de mapeo Unicode
- **Plan Fase 1**: ASCII simple
- **Plan Fase 2**: Unicode completo con std.unicode

#### ⚠️ toUpperCase()
**Viabilidad: MEDIA**
- Conversión a mayúsculas
- Mismos problemas que toLowerCase()
- **Plan**: Igual que toLowerCase()

#### ❌ toLocaleLowerCase()
**Viabilidad: BAJA**
- Requiere información de locale (idioma/región)
- Reglas complejas (ej: 'i' turca)
- **Plan**: Fase 3 o no implementar
- Marcar como "not implemented"

#### ❌ toLocaleUpperCase()
**Viabilidad: BAJA**
- Mismos problemas que toLocaleLowerCase()
- **Plan**: Fase 3 o no implementar

---

### 3.5 Padding y Trimming

#### ✅ padStart()
**Viabilidad: ALTA**
- Agregar padding al inicio
- **Plan**: Calcular padding necesario, allocar buffer, copiar
- Manejar strings de padding multi-carácter

#### ✅ padEnd()
**Viabilidad: ALTA**
- Agregar padding al final
- Similar a padStart()

#### ✅ trim()
**Viabilidad: ALTA**
- Remover whitespace de ambos lados
- **Plan**: Identificar índices de primer/último no-whitespace
- Definir whitespace según Unicode o ASCII

#### ✅ trimStart() / trimLeft()
**Viabilidad: ALTA**
- Remover whitespace del inicio
- **Plan**: Encontrar primer no-whitespace, retornar slice

#### ✅ trimEnd() / trimRight()
**Viabilidad: ALTA**
- Remover whitespace del final
- **Plan**: Encontrar último no-whitespace, retornar slice

---

### 3.6 Comparación y Locale

#### ⚠️ localeCompare()
**Viabilidad: MEDIA-BAJA**
- Comparación sensible a locale
- Requiere:
  - Datos de collation Unicode (CLDR)
  - Lógica compleja de sorting
- **Plan**:
  - Fase 1: Comparación simple por code points
  - Fase 2: Integrar biblioteca ICU o similar
- No prioritario

#### ⚠️ normalize()
**Viabilidad: MEDIA**
- Normalización Unicode (NFC, NFD, NFKC, NFKD)
- **Consideraciones**:
  - Zig tiene std.unicode pero limitado
  - Requiere tablas de normalización Unicode
- **Plan**:
  - Investigar si std.unicode.norm existe
  - Si no, implementar o usar biblioteca externa
- Útil para comparaciones correctas

---

### 3.7 Conversión y Validación

#### ✅ toString()
**Viabilidad: ALTA (redundante)**
- En JS convierte String object a primitivo
- En Zig: ya es un slice, no necesario
- **Plan**: No implementar o simplemente retornar self

#### ✅ valueOf()
**Viabilidad: ALTA (redundante)**
- Similar a toString()
- **Plan**: No implementar

#### ⚠️ isWellFormed()
**Viabilidad: MEDIA**
- Verifica que no haya lone surrogates (UTF-16)
- En Zig con UTF-8:
  - Verificar que sea UTF-8 válido
- **Plan**: Usar std.unicode.utf8ValidateSlice
- Útil para validación

#### ⚠️ toWellFormed()
**Viabilidad: MEDIA**
- Reemplaza lone surrogates con U+FFFD
- En Zig:
  - Reemplazar secuencias UTF-8 inválidas con �
- **Plan**: Iterar, validar, reemplazar inválidos
- Necesita allocator

---

### 3.8 Iteración

#### ✅ [Symbol.iterator]()
**Viabilidad: ALTA**
- Iterador por code points
- **Plan**: En Zig crear struct Iterator
```zig
pub const Iterator = struct {
    string: []const u8,
    index: usize,

    pub fn next(self: *Iterator) ?[]const u8 { ... }
};
```
- Muy idiomático en Zig

---

### 3.9 HTML Wrapper Methods

#### 🗑️ anchor(), big(), blink(), bold(), fixed(), etc.
**Viabilidad: N/A - DEPRECATED**
- **Todos deprecated en JS moderno**
- **Plan**: NO IMPLEMENTAR
- Sin valor práctico
- Usar DOM APIs en su lugar

---

## 4. RESUMEN POR PRIORIDAD

### Fase 1 - Core (Implementación Inmediata)
**Métodos esenciales y de alta viabilidad**

#### Propiedades
- ✅ length (con variantes byte/codepoint)

#### Construcción
- ✅ fromCharCode()
- ✅ fromCodePoint()

#### Acceso a caracteres
- ✅ at()
- ✅ charAt()
- ✅ charCodeAt()
- ✅ codePointAt()

#### Búsqueda (sin regex)
- ✅ indexOf()
- ✅ lastIndexOf()
- ✅ includes()
- ✅ startsWith()
- ✅ endsWith()

#### Manipulación básica
- ✅ concat()
- ✅ slice()
- ✅ substring()
- ✅ repeat()
- ✅ split() (solo string delimiters)
- ✅ replace() (solo strings literales)
- ✅ replaceAll() (solo strings literales)

#### Padding y trimming
- ✅ padStart()
- ✅ padEnd()
- ✅ trim()
- ✅ trimStart()
- ✅ trimEnd()

#### Iteración
- ✅ Iterator (Symbol.iterator equivalente)

**Total Fase 1: ~25 métodos**

---

### Fase 2 - Extended (Funcionalidad Extendida)

#### Conversión de caso
- ⚠️ toLowerCase() (Unicode completo)
- ⚠️ toUpperCase() (Unicode completo)

#### Normalización
- ⚠️ normalize()
- ⚠️ isWellFormed()
- ⚠️ toWellFormed()

#### Otros
- ⚠️ String.raw()

**Total Fase 2: ~6 métodos**

---

### Fase 3 - Regex & Locale (Avanzado)

#### Regex
- ⚠️ match()
- ⚠️ matchAll()
- ⚠️ search()
- ⚠️ split() (con regex)
- ⚠️ replace() (con regex)
- ⚠️ replaceAll() (con regex)

#### Locale
- ❌ toLocaleLowerCase()
- ❌ toLocaleUpperCase()
- ❌ localeCompare()

**Total Fase 3: ~9 métodos (complejo)**

---

### No Implementar
- 🗑️ substr() - deprecated
- 🗑️ Todos los HTML wrappers (13 métodos)
- 🗑️ toString() / valueOf() (redundante en Zig)

---

## 5. DECISIONES DE DISEÑO IMPORTANTES

### 5.1 Gestión de Memoria
```zig
// Opción A: Siempre retornar owned strings
pub fn concat(allocator: Allocator, strings: []const []const u8) ![]u8

// Opción B: Permitir opción de slice vs owned
pub fn slice(self: []const u8, start: isize, end: isize) []const u8
pub fn sliceOwned(allocator: Allocator, self: []const u8, start: isize, end: isize) ![]u8
```

**Decisión**: Usar ambos patrones según el método
- Métodos que no modifican longitud: retornar slices
- Métodos que modifican/crean: requieren allocator

### 5.2 Indexación: Bytes vs Code Points
```zig
// Opción A: Siempre bytes (más rápido, menos compatible)
pub fn charAt(self: []const u8, index: usize) []const u8

// Opción B: Code points (más lento, más compatible con JS)
pub fn charAtCodePoint(self: []const u8, index: usize) []const u8

// Opción C: Ambos disponibles
pub fn byteAt(self: []const u8, byte_index: usize) u8
pub fn codePointAt(self: []const u8, cp_index: usize) u21
```

**Decisión**: Proveer ambas variantes, documentar claramente
- Métodos con "byte" prefix: trabajan con bytes
- Métodos sin prefix: trabajan con code points (compatible JS)
- Documentar performance trade-offs

### 5.3 Manejo de UTF-8 Inválido
```zig
// ¿Qué hacer con bytes UTF-8 inválidos?
// Opción A: Error
pub fn codePointAt(self: []const u8, index: usize) !u21

// Opción B: Reemplazar con U+FFFD (�)
pub fn codePointAt(self: []const u8, index: usize) u21

// Opción C: Opción configurable
pub const Options = struct {
    on_invalid: enum { err, replace, skip } = .replace,
};
```

**Decisión**: Por defecto usar approach B (replacement)
- Más compatible con comportamiento de JS
- Métodos "strict" pueden retornar error
- isWellFormed() para validación previa

### 5.4 API Estructura
```zig
// Opción A: Namespace con funciones
const zstring = @import("zstring");
const result = zstring.toUpperCase(allocator, my_string);

// Opción B: Struct wrapper con métodos
const ZString = @import("zstring").ZString;
var zstr = try ZString.init(allocator, "hello");
defer zstr.deinit();
const upper = try zstr.toUpperCase();

// Opción C: Mixto (funciones + optional wrapper)
const zstring = @import("zstring");
// Uso directo
const upper1 = try zstring.toUpperCase(allocator, "hello");
// O con wrapper
var zstr = zstring.ZString{ .data = "hello" };
const upper2 = try zstr.toUpperCase(allocator);
```

**Decisión**: Opción C (mixto)
- Funciones puras para casos simples
- Struct opcional para encadenar operaciones
- Mayor flexibilidad para el usuario

---

## 6. DEPENDENCIAS EXTERNAS A INVESTIGAR

### 6.1 Regex
- **Opciones**:
  - [zig-regex](https://github.com/tiehuis/zig-regex) - RE2 style
  - [regez](https://github.com/Vexu/regez) - Pure Zig
  - Bindings a PCRE2
- **Investigar**: Performance, compatibilidad ECMAScript, mantenimiento

### 6.2 Unicode
- **Zig stdlib**: std.unicode (limitado pero suficiente para básico)
- **Tablas Unicode**: Generar desde UCD (Unicode Character Database)
- **ICU bindings**: Para locale-aware operations (Fase 3)

### 6.3 Normalización Unicode
- Implementar con tablas generadas
- O bindings a biblioteca C existente

---

## 7. PLAN DE TESTING

### Tests necesarios
- ✅ Tests unitarios para cada método
- ✅ Tests de edge cases:
  - Strings vacíos
  - Índices negativos
  - Índices fuera de rango
  - UTF-8 multi-byte
  - Emojis y caracteres especiales
- ✅ Tests de memoria (no leaks)
- ✅ Benchmarks de performance
- ✅ Tests de compatibilidad con JS (casos de uso comunes)

### Herramientas
- Zig built-in test framework
- Fuzzing para robustez
- Memory sanitizers

---

## 8. CONCLUSIÓN

### Viabilidad General: ⚠️ ALTA (con fases)

**Fase 1 (Core)**: Completamente viable, ~25 métodos esenciales
- Timeframe estimado: Base sólida y funcional
- Cubre 80% de casos de uso comunes

**Fase 2 (Extended)**: Viable con esfuerzo moderado, ~6 métodos
- Requiere trabajo en Unicode correctness
- Mejora significativa en robustez

**Fase 3 (Regex & Locale)**: Viable pero requiere dependencias externas
- Regex: Necesita biblioteca o implementación compleja
- Locale: Muy complejo, posiblemente no prioritario

### Recomendación
1. **Comenzar con Fase 1**: Crear API sólida y bien documentada
2. **Diseñar para extensibilidad**: Dejar espacio para Fase 2 y 3
3. **Documentar diferencias con JS**: Especialmente UTF-16 vs UTF-8
4. **Proveer ejemplos claros**: Mostrar ownership y memoria explícita
5. **Tests exhaustivos**: Garantizar correctness desde el inicio

### Próximos Pasos
1. Definir estructura del proyecto
2. Crear API sketch en código
3. Implementar primeros métodos (charAt, indexOf, etc.)
4. Establecer patterns de testing
5. Iterar y expandir
