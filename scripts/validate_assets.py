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
try:
    composition = json.loads((root/'heads.json').read_text())
    assert set(composition['heads']) == set(heads)
    reference = composition['referenceTorsoWidth']
    ratio = composition['headToTorsoRatio']
    assert reference > 0 and 1 < ratio < 2
    canvas = composition['canvas']
    assert all(math.isfinite(canvas[k]) for k in ['halfWidth', 'top', 'bottom'])
    assert canvas['halfWidth'] > 0 and canvas['top'] < 0 < canvas['bottom']
    for name, layout in composition['heads'].items():
        assert all(isinstance(v, (float, int)) and math.isfinite(v) for v in layout.values())
        assert -45 <= layout['rotationDegrees'] <= 45
        assert layout['visibleWidth'] > 0
        assert 0 <= layout['chinX'] < layout['sourceWidth']
        assert 0 <= layout['chinY'] < layout['sourceHeight']
        assert 0 <= layout['overlap'] < layout['targetWidth'] / 4
        assert math.isclose(layout['targetWidth'], reference * ratio)
        if name in sizes:
            assert sizes[name] == (layout['sourceWidth'], layout['sourceHeight'])
    print('Head layouts: three upright chin anchors, consistent visible size and valid composition canvas')
except (OSError, ValueError, KeyError, AssertionError, TypeError) as error:
    errors.append(f'Head composition: {error}')
if len({sizes[name] for name in heads if name in sizes})>1:
    errors.append('Head canvas sizes differ; inspect positioning before release')
# The small console uses the approved shell and supplied landscape originals.
console_root = root.parent/'WidgetConsole'
for name in ['mini-console', 'nature-hill', 'nature-golden-hills', 'nature-desert', 'nature-mountains']:
    path = console_root/(name+'.png')
    if not path.exists():
        missing.append('WidgetConsole/'+path.name)
        continue
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or len(data)<33:
        errors.append(f'{path.name}: invalid PNG')
        continue
    width, height = struct.unpack('>II', data[16:24])
    if width<=0 or height<=0: errors.append(f'{path.name}: invalid dimensions')
    if name=='mini-console' and (width,height)!=(1254,1254):
        errors.append('Console shell dimensions do not match source-coordinate layout')
    print(f'{path.name}: {width}x{height}')
if missing: print('MISSING ASSETS: '+', '.join(missing))
for error in errors: print(error, file=sys.stderr)
if errors or (args.require_assets and missing): sys.exit(1)
