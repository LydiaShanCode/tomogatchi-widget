# Character assets

Photographic head cutouts remain unchanged:
- connor-fed.png — smiling (FED)
- connor-hungry.png — unimpressed without glasses (HUNGRY)
- connor-starving.png — glasses (TIRED)

The approved abstract body packs replace the six older two-frame bodies:
- idle-sheet.png — five frames, subtle standing/arm pulse (original approved version)
- hungry-sheet.png — five frames, tummy-holding with growl marks in frames 2–4
- dancing-sheet.png — five frames, dancing stick arms and legs

Sheets are copied byte-for-byte from the approved generated packs. Each has a
transparent background, light torso and dark stick limbs for light backgrounds.
No body sprite contains a head. The photographic heads are separate layers.

heads.json corrects each photo's original sideways tilt with view rotation about
its own chin anchor (-2° smiling, -32° unimpressed, -13° glasses). All expressions
have a consistent visible head width, 1.4 times the widest reference torso. Each
chin overlaps the torso at the centered neck attachment point as in the supplied
reference screenshots. A shared composition canvas fits the complete character
without changing scale/position as frames animate. PNG photo bytes are unchanged.

animations.json records five source rectangles and per-frame neck anchors for
each sheet plus a common pixel scale. The renderer displays a clipped atlas cell;
it never rewrites the source PNGs. Anchors use the upper torso's center so heads
remain centered while arms and legs move. Verify final alignment on a device.

Idle plays at 180 ms/frame, hungry at 150 ms/frame and dancing at 120 ms/frame.
In the app, the star button plays a three-second dance and returns to the current
mood. Hungry and tired use the hungry body; their photographic heads still differ.
Eating a gift briefly uses the fed head and idle body. Widgets display static
frame 1; they do not run a continuous dance animation.

Run python3 scripts/validate_assets.py --require-assets before building.
