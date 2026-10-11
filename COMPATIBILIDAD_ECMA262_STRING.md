# Compatibilidad funcional con ECMA-262 String

Referencia: [String Objects de ECMA-262](https://tc39.es/ecma262/#sec-string-objects), con sus algoritmos delegados de RegExp. La versión Unicode incluida es 17.0.0. No se selecciona una edición anual distinta del objetivo solicitado.

## Denominador y porcentajes

El inventario cuenta **39 operaciones**: 35 del prototipo (incluido el iterador), tres fábricas estáticas y length. Los aliases trimLeft/trimRight no aumentan el denominador. Constructor/boxing, propiedades del prototipo, coerciones de objetos, dispatch de símbolos y descriptores de propiedades corresponden a un runtime JavaScript y no son parte de esta biblioteca tipada. Annex B y ECMA-402 tampoco se incluyen.

- **Disponibilidad: 39/39 = 100%**. Hay una función Zig para cada operación del perfil.
- **Estado verificado del perfil: 33/39 = 84,62%**. Seis familias que admiten regex permanecen parciales, aunque sus rutas literales y muchos patrones regex están probados. Este porcentaje clasifica familias funcionales, no algoritmos ni casos normativos.
- **Conformidad semántica universal: no determinada**. No debe derivarse del número de métodos, del estado de la matriz ni del porcentaje de pruebas aprobadas. La dependencia regex tiene restricciones conocidas.

## Matriz

| Operación | Entrada Zig recomendada | Estado |
| --- | --- | --- |
| `length` | `ZString.lengthConst` | Perfil verificado |
| `String.fromCharCode` | `ZString.fromCharCodeEcma` | Perfil verificado |
| `String.fromCodePoint` | `ZString.fromCodePointEcma` | Perfil verificado |
| `String.raw` | `ZString.raw` | Perfil verificado |
| `at` | `ZString.at` | Perfil verificado |
| `charAt` | `ZString.charAt` | Perfil verificado |
| `charCodeAt` | `ZString.charCodeAt` | Perfil verificado |
| `codePointAt` | `ZString.codePointAt` | Perfil verificado |
| `concat` | `ZString.concat` | Perfil verificado |
| `endsWith` | `ZString.endsWith` | Perfil verificado |
| `includes` | `ZString.includes` | Perfil verificado |
| `indexOf` | `ZString.indexOf` | Perfil verificado |
| `isWellFormed` | `ZString.isWellFormed` | Perfil verificado |
| `lastIndexOf` | `ZString.lastIndexOf` | Perfil verificado |
| `localeCompare` | `ZString.localeCompare` | Perfil verificado |
| `match` | `CompiledRegex.match` | Parcial: restricciones RegExp |
| `matchAll` | `CompiledRegex.matchAll` | Parcial: restricciones RegExp |
| `normalize` | `ZString.normalizeStrict` | Perfil verificado |
| `padEnd` | `ZString.padEnd` | Perfil verificado |
| `padStart` | `ZString.padStart` | Perfil verificado |
| `repeat` | `ZString.repeat` | Perfil verificado |
| `replace` | `ZString.replaceLiteral / CompiledRegex.replace` | Parcial: restricciones RegExp |
| `replaceAll` | `ZString.replaceAllLiteral / CompiledRegex.replaceAll` | Parcial: restricciones RegExp |
| `search` | `CompiledRegex.search` | Parcial: restricciones RegExp |
| `slice` | `ZString.slice` | Perfil verificado |
| `split` | `ZString.split / CompiledRegex.split` | Parcial: restricciones RegExp |
| `startsWith` | `ZString.startsWith` | Perfil verificado |
| `substring` | `ZString.substring` | Perfil verificado |
| `toLocaleLowerCase` | `ZString.toLocaleLowerCase` | Perfil verificado |
| `toLocaleUpperCase` | `ZString.toLocaleUpperCase` | Perfil verificado |
| `toLowerCase` | `ZString.toLowerCase` | Perfil verificado |
| `toString` | `ZString.toStringAlloc` | Perfil verificado |
| `toUpperCase` | `ZString.toUpperCase` | Perfil verificado |
| `toWellFormed` | `ZString.toWellFormed` | Perfil verificado |
| `trim` | `ZString.trim` | Perfil verificado |
| `trimEnd` | `ZString.trimEnd` | Perfil verificado |
| `trimStart` | `ZString.trimStart` | Perfil verificado |
| `valueOf` | `ZString.valueOfAlloc` | Perfil verificado |
| `iterator` | `ZString.iterator` | Perfil verificado |

“Perfil verificado” significa que está implementado y tiene evidencia en las suites del repositorio; no certifica todos los posibles inputs. Para localeCompare el contrato es equivalencia canónica y orden total determinista del locale raíz, con argumentos ECMA-402 reservados.

## Evidencia y unidades de medida

- La prueba de API congela tipos de parámetros y payloads de retorno de 99 funciones públicas del commit inicial `ee08516`. Una prueba adicional congela los conjuntos de errores de 102 funciones/aliases originales; se conservan los campos públicos anteriores. No equivale a una garantía ABI binaria entre versiones de Zig.
- Selección Test262 fijada a `2e0a56762801e275a9fdf96dc49d90ba0cddcf63`: **55 aserciones** adaptadas de ocho fuentes oficiales, con originales y licencia en `tests/spec/data/test262`. Incluyen acceso relativo, padding de parejas, repair, decoding, sigma contextual y errores de forma de normalización. Los checks de `typeof` se excluyen; `normalize(null)` se adapta al string tipado `"null"` después de la coerción JS.
- `string_oracle.json`: **9.216 casos** deterministas frente a Node v26.5.0, comparando UTF-16, valores numéricos y booleanos. Semilla y SHA-256 en `tests/spec/data/ORACLE.txt`. Se ejecuta en Zig sin iniciar Node.
- `NormalizationTest.txt`: **20.034 registros** oficiales Unicode; 20 comprobaciones por registro, **400.680 comparaciones** entre las cuatro formas.
- `UnicodeData.txt` y `SpecialCasing.txt`: mappings simples y completos incondicionales; sigma final se verifica mediante pruebas contextuales adicionales.
- Regresiones: minInt, corte/padding de medias parejas, split limit=0, capturas ausentes, matches vacíos, plantillas, flags, callbacks y sujeto preparado.
- Fallos de asignación: inyección exhaustiva en las rutas nuevas de normalización/casing/padding/fábricas/split y regex. Prueba de ausencia de nuevas asignaciones en ejecución preparada tras calentamiento.

Estos corpus y la suite Zig no ejecutan Test262 completo. Los casos que exigen un runtime para coerciones, getters, objetos RegExp personalizados o símbolos no son trasladables mediante una mera llamada a esta API. No se suman comparaciones Unicode y casos JS para fabricar un porcentaje ECMA-262.

## Diferencias de API conservadas

| Contrato anterior | Alternativa para semántica más estricta |
| --- | --- |
| Fábricas que rechazan sustitutos aislados | `fromCharCodeEcma` y `fromCodePointEcma` |
| `normalize` copia el input ante forma inválida | `normalizeStrict` devuelve `InvalidNormalizationForm` |
| Regex con fallback silencioso, interfaz de bytes y 15 grupos | `CompiledRegex` devuelve errores y capturas exactas UTF-16 |
| Reemplazo regex antiguo inserta texto crudo | API compilada con plantillas/callbacks o APIs literales |
| `splitRegex` usa `""` para una captura ausente | `CompiledRegex.split` mantiene `null` |

## Límites de RegExp pendientes

El backend fijado es [zregex 0.9.1](https://github.com/carlos-sweb/z-regex/tree/2a48ab64a26ea5dd0a4d9edcfc51c6f76eb44c40), que requiere Zig 0.17.0. Esta actualización migra el compilador y conserva la API y la semántica del backend; no elimina sus restricciones ECMA-262. Su documentación declara `UnsupportedFeature` para modifiers, determinados sets/case folding bajo `iv` y ciertas formas complejas de lookbehind bajo Unicode o con lookarounds anidados. La API estricta propaga estas limitaciones; los wrappers históricos mantienen sus valores de respaldo.

Para cerrar esas seis familias: actualizar el backend con soporte verificado, añadir casos diferenciales/Test262 adaptados para cada restricción, repetir pruebas de memoria y validar que siguen pasando los contratos antiguos. **Hasta entonces no se declara 100% de funcionalidad semántica ECMA-262 String.**

## Informe reproducible

`python3 tools/report_coverage.py` calcula disponibilidad y estados desde `tests/spec/coverage.json`, y cuenta los corpus. La matriz se revisa junto con las pruebas al incorporar operaciones o eliminar restricciones.
