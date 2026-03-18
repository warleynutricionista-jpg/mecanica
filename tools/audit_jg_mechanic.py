#!/usr/bin/env python3
from __future__ import annotations

import argparse
import glob
import json
from pathlib import Path
from typing import Dict, List

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / 'jg-mechanic'

MANIFEST_PATTERNS = {
    'shared_scripts': [
        'config/*.lua',
        'locales/*.lua',
        'shared/*.lua',
        'framework/main.lua',
    ],
    'client_scripts': [
        'framework/**/cl-*.lua',
        'client/cl-*.lua',
    ],
    'server_scripts': [
        'framework/**/sv-*.lua',
        'server/sv-*.lua',
    ],
}


def classify_file(path: Path) -> Dict[str, object]:
    data = path.read_bytes()
    first4 = data[:4]
    entry: Dict[str, object] = {
        'path': path.relative_to(RESOURCE).as_posix(),
        'size': len(data),
        'starts_with': first4.hex(),
        'type': 'text',
        'issues': [],
    }

    if first4 == b'FXAP':
        entry['type'] = 'fxap_escrow_blob'
        entry['issues'].append('Not plain Lua source; this is a FiveM Asset Escrow protected blob.')
        return entry

    if data.startswith(b'\xef\xbb\xbf'):
        entry['issues'].append('UTF-8 BOM present')
    if data.startswith((b'\xff\xfe', b'\xfe\xff')):
        entry['issues'].append('UTF-16 BOM present')
    if b'\x00' in data:
        entry['issues'].append('Contains NUL bytes')

    try:
        data.decode('utf-8')
        entry['encoding'] = 'utf-8'
    except UnicodeDecodeError as exc:
        entry['type'] = 'binary_or_non_utf8'
        entry['issues'].append(f'UTF-8 decode failed: {exc}')

    return entry


def manifest_matches() -> Dict[str, List[str]]:
    result: Dict[str, List[str]] = {}
    for group, patterns in MANIFEST_PATTERNS.items():
        matches: List[str] = []
        for pattern in patterns:
            for match in sorted(glob.glob(str(RESOURCE / pattern), recursive=True)):
                matches.append(Path(match).relative_to(RESOURCE).as_posix())
        result[group] = matches
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description='Audit jg-mechanic Lua files for escrow/binary/encoding issues.')
    parser.add_argument('--json', action='store_true', help='Print JSON instead of a human-readable report.')
    args = parser.parse_args()

    files = sorted(RESOURCE.rglob('*.lua'))
    entries = [classify_file(path) for path in files]
    manifest = manifest_matches()

    summary = {
        'resource': RESOURCE.as_posix(),
        'total_lua_files': len(entries),
        'fxap_escrow_blobs': sum(1 for entry in entries if entry['type'] == 'fxap_escrow_blob'),
        'plain_text_lua': sum(1 for entry in entries if entry['type'] == 'text'),
        'binary_or_non_utf8': [entry['path'] for entry in entries if entry['type'] == 'binary_or_non_utf8'],
        'manifest_matches': manifest,
        'files': entries,
    }

    if args.json:
        print(json.dumps(summary, indent=2, ensure_ascii=False))
        return 0

    print('jg-mechanic audit report')
    print('=' * 80)
    print(f"Total .lua files: {summary['total_lua_files']}")
    print(f"FXAP escrow blobs: {summary['fxap_escrow_blobs']}")
    print(f"Plain UTF-8 Lua files: {summary['plain_text_lua']}")
    print()

    if summary['fxap_escrow_blobs']:
        print('Protected FXAP files detected:')
        for entry in entries:
            if entry['type'] == 'fxap_escrow_blob':
                print(f"  - {entry['path']}")
        print()
        print('These files are escrow-protected binaries, not corrupted text encodings.')
        print('If FiveM logs `syntax error near \"<\\1>\"` for them, the fix is to restore the official escrow package / entitlement path, not to re-encode the files.')
        print()

    suspicious = [entry for entry in entries if entry['type'] != 'fxap_escrow_blob' and entry['issues']]
    if suspicious:
        print('Plain-text files with encoding flags:')
        for entry in suspicious:
            print(f"  - {entry['path']}: {', '.join(entry['issues'])}")
        print()
    else:
        print('No BOM/UTF-16/NUL-byte problems detected in the plain-text Lua files.')
        print()

    print('fxmanifest.lua glob resolution:')
    for group, matches in manifest.items():
        print(f'  {group}: {len(matches)} matches')
        for match in matches:
            print(f'    - {match}')

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
