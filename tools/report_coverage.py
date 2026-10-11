#!/usr/bin/env python3
"""Report capability/status counts, never a universal conformance percentage."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
matrix = json.loads((root / 'tests/spec/coverage.json').read_text())
rows = matrix['operations']
assert len(rows) == 39 and len({row['operation'] for row in rows}) == len(rows)
available = sum(row['available'] for row in rows)
verified = sum(row['status'] == 'verified_profile' for row in rows)
normalization = sum(1 for line in (root / 'tests/spec/data/NormalizationTest.txt').read_text().splitlines() if line.strip() and line[0] not in '#@')
oracle = len(json.loads((root / 'tests/spec/data/string_oracle.json').read_text()))
print(f"{matrix['standard']}: {matrix['profile']}")
print(f'Available operations: {available}/{len(rows)} ({100*available/len(rows):.2f}%)')
print(f'Verified-profile families: {verified}/{len(rows)} ({100*verified/len(rows):.2f}%)')
print(f'Partial RegExp families: {len(rows)-verified}')
print(f'Node differential cases: {oracle}')
selected = len(json.loads((root / 'tests/spec/data/test262_oracle.json').read_text()))
print(f'Adapted Test262 assertions: {selected}; source files: 8')
print(f'Official normalization records: {normalization}; comparisons: {normalization*20}')
print('Universal ECMA-262 semantic conformance: not determined; Test262 full suite not executed.')
