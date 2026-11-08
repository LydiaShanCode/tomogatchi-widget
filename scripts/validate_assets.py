#!/usr/bin/env python3
"""Validate supplied originals without rewriting them. Release builds require all nine."""
from pathlib import Path
import argparse, struct, hashlib, sys, json
root=Path(__file__).resolve().parent.parent/'Resources/Character'
names=['connor-fed','connor-hungry','connor-starving','idle_01','idle_02','hungry_01','hungry_02','low_energy_01','low_energy_02']
parser=argparse.ArgumentParser();parser.add_argument('--require-assets',action='store_true');args=parser.parse_args()
missing=[];sizes={};errors=[]
for name in names:
    path=root/(name+'.png')
    if not path.exists():missing.append(path.name);continue
    data=path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or len(data)<33:errors.append(f'{path.name}: invalid PNG');continue
    width,height,depth,color=struct.unpack('>IIBB',data[16:26]);sizes[name]=(width,height)
    if not width or not height:errors.append(f'{path.name}: invalid dimensions')
    if color not in (4,6) and b'tRNS' not in data:errors.append(f'{path.name}: transparency required')
    print(f'{path.name}: {width}x{height}, SHA256 {hashlib.sha256(data).hexdigest()}')
# Supplied body sprites have different canvases. Verify their explicit layout
# metadata instead of requiring destructive image resizing or padding.
layouts = json.loads((root/'layout.json').read_text())
for name in names[3:]:
    layout = layouts.get(name)
    if not layout:
        errors.append(f'{name}: missing layout metadata')
        continue
    if name in sizes and sizes[name] != (layout['width'], layout['height']):
        errors.append(f'{name}: source dimensions do not match layout metadata')
    if not (0 < layout['visibleHeight'] <= layout['height'] and 0 <= layout['neckX'] < layout['width'] and 0 <= layout['neckY'] < layout['visibleHeight']):
        errors.append(f'{name}: invalid viewport or neck anchor')
if len({sizes[name] for name in names[:3] if name in sizes}) > 1:
    errors.append('Inconsistent head canvas sizes; inspect photo positioning before release')
if missing:print('MISSING ORIGINALS: '+', '.join(missing))
for error in errors:print(error,file=sys.stderr)
if errors or (args.require_assets and missing):sys.exit(1)
