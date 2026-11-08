# Original character assets

Received all six transparent body PNGs from `conner_widget_sprites.zip`:
- idle_01.png / idle_02.png
- hungry_01.png / hungry_02.png
- low_energy_01.png / low_energy_02.png

The PNGs are stored byte-for-byte as supplied. The archive README specifies
alternating frames every 250–450 ms; the main app uses 350 ms. Widgets use frame 1.

The three supplied photographs now have transparent head cutouts:
- connor-fed.png — smiling (Photo 1)
- connor-hungry.png — unimpressed, without glasses (Photo 2)
- connor-starving.png — glasses (Photo 3); displayed as TIRED

This mapping follows the user's revised choice. The cutouts were prepared with
background removal from the supplied photographs, on matching transparent square
canvases. Original photo uploads remain unchanged. Do not intentionally redraw,
retouch, or substitute faces. Final neck alignment still requires native previews.

The six body canvases differ in size. `layout.json` records original dimensions,
per-frame neck anchors, and visible heights; the shared renderer uses a common
pixel scale without rewriting images. Both low-energy files include stray sheet
captions below the full body. Their viewports exclude only the bottom annotation
strip (below source y=130), preserving the body and the widget's one-word label.
Final photo-to-neck alignment still needs visual acceptance with the original heads.
Run `python3 scripts/validate_assets.py --require-assets` before a release.
