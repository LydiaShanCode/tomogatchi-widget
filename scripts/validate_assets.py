#!/usr/bin/env python3
"""Validate photographic heads and five-frame body atlases without rewriting images."""
from pathlib import Path
import argparse, struct, hashlib, sys, json, math
root = Path(__file__).resolve().parent.parent/'Resources/Character'
parser = argparse.ArgumentParser()
parser.add_argument('--require-assets', action='store_true')
args = parser.parse_args()
heads = ['connor-fed', 'connor-hungry', 'connor-starving']
animations = ['idle', 'hungry', 'dancing']
missing, errors, sizes = [], [], {}
for name in heads + [a+'-sheet' for a in animations]:
    path = root/(name+'.png')
    if not path.exists():
        missing.append(path.name)
        continue
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or len(data)<33:
        errors.append(f'{path.name}: invalid PNG')
        continue
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    sizes[name] = (width, height)
    if not width or not height: errors.append(f'{path.name}: invalid dimensions')
    if color not in (4,6) and b'tRNS' not in data: errors.append(f'{path.name}: transparency required')
    print(f'{path.name}: {width}x{height}, SHA256 {hashlib.sha256(data).hexdigest()}')
try:
    atlas = json.loads((root/'animations.json').read_text())
    scale = atlas['pixelScale']
    assert isinstance(scale, (float,int)) and math.isfinite(scale) and 0 < scale < 1
    assert set(atlas['animations']) == set(animations)
    for name in animations:
        sheet = atlas['animations'][name]
        assert sheet['image'] == name+'-sheet', f'{name}: wrong sheet'
        if sheet['image'] in sizes:
            assert sizes[sheet['image']] == (sheet['width'],sheet['height']), f'{name}: dimensions mismatch'
        frames = sheet['frames']
        assert len(frames) == 5, f'{name}: expected five frames'
        edge = 0
        for frame in frames:
            assert all(isinstance(frame[k],int) for k in ['x','y','width','height'])
            assert frame['x']==edge and frame['y']==0, f'{name}: gaps or overlaps in atlas cells'
            assert frame['width']>0 and frame['height']==sheet['height']
            assert 0 <= frame['neckX'] < frame['width'] and 0 <= frame['neckY'] < frame['height']
            edge += frame['width']
        assert edge==sheet['width'], f'{name}: atlas cells do not cover the sheet'
        print(f'{name}: five frames with valid source rectangles and neck anchors')
except (OSError, ValueError, KeyError, AssertionError, TypeError) as error:
    errors.append(f'Animation atlas: {error}')
if len({sizes[name] for name in heads if name in sizes})>1:
    errors.append('Head canvas sizes differ; inspect positioning before release')
if missing: print('MISSING ASSETS: '+', '.join(missing))
for error in errors: print(error, file=sys.stderr)
if errors or (args.require_assets and missing): sys.exit(1)
