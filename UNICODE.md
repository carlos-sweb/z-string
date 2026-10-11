# Unicode reproducible

La implementación usa **Unicode 17.0.0**, publicado por Unicode Consortium. Es una versión de los datos Unicode, distinta del identificador del estándar **ECMA-262 String**.

## Fuentes y licencia

Directorio oficial: <https://www.unicode.org/Public/17.0.0/ucd/>.

- `UnicodeData.txt`: mappings simples de case conversion, descomposiciones y clases combinantes.
- `SpecialCasing.txt`: mappings completos incondicionales. La condición independiente del locale, sigma final, se ejecuta en `case.zig` usando `Cased` y `Case_Ignorable`.
- `DerivedCoreProperties.txt`: propiedades de contexto del casing.
- `DerivedNormalizationProps.txt`: exclusiones completas de composición.
- `PropList.txt`: `Soft_Dotted`, reservado para futuras extensiones de locale.
- `NormalizationTest.txt`: corpus oficial de conformidad de normalización.

Los hashes SHA-256 de las cinco entradas del generador se encuentran en [SOURCES.txt](src/unicode/SOURCES.txt). La [licencia Unicode v3](src/unicode/LICENSE.txt) acompaña los datos y sus derivados.

## Regeneración

Descargar los cinco archivos del generador desde el directorio oficial a una carpeta externa. El build habitual no realiza estas descargas.

```sh
python3 tools/generate_unicode.py /tmp/ucd-17
python3 tools/generate_unicode.py /tmp/ucd-17 --check
```

El generador utiliza Python estándar y `zig fmt --stdin`. Produce tablas ordenadas para búsqueda binaria y un manifiesto de hashes. Comprueba los límites de offset, el tamaño máximo de mappings y la expansión recursiva de descomposición (18 puntos de código), además de detectar ciclos. `--check` no modifica los archivos generados.

Para actualizar Unicode, fijar primero una versión nueva, actualizar fuentes, manifests y corpus; regenerar y ejecutar todas las pruebas. No mezclar fuentes de distintas versiones. `zstring.unicode_version` informa la versión incluida.

## Algoritmos y límites

- Casing: mappings completos, ruta ASCII con una asignación, sustitutos preservados y sigma final contextual. Locale básico fijo raíz; ECMA-402 no está implementado.
- Normalización: descomposición recursiva canónica/compatible, orden estable por clase combinante, composición bloqueada, exclusiones y Hangul algorítmico. Las formas de normalización mantienen sustitutos aislados.
- Comparación: NFD constante en memoria, equivalencia canónica y orden determinista. Las secuencias largas de marcas tienen coste O(k²).
- Bytes inválidos que no representan UTF-8/WTF-8 conservan el respaldo histórico de las funciones anteriores; no forman parte de la garantía ECMA-262.

## Corpus

`tests/spec/data` incluye los originales `UnicodeData.txt`, `SpecialCasing.txt` y `NormalizationTest.txt`. La prueba de casing interpreta los archivos originales independientemente del formato Zig generado. La prueba de normalización aplica 20 comprobaciones a cada uno de los 20.034 registros: **400.680 comparaciones normativas**. Su número de pruebas Zig es pequeño porque cada test recorre el corpus completo.
