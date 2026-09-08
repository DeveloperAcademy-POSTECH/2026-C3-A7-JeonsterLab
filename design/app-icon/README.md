# Approved WatchMotion Editor icon

Source: approved-reference.png, supplied by the user.
Production texture: full-bleed-master.png. Prepared with the built-in image generation tool to remove the presentation margin; opaque full-bleed black background, red brackets and white motion waveform. sips exports the texture to the existing iOS/watchOS 1024px slots and macOS 16–1024px slots.

The macOS background-extraction attempts returned RGB checkerboard pixels rather than real alpha and were not installed. The same opaque square texture is currently used on macOS; it does not have a pre-rendered rounded transparent silhouette.

Device app display names and product filenames are WatchMotion Editor; internal target/scheme names remain stable. Existing storage and network protocol identifiers remain compatible.

Validation: unsigned Debug iOS+watchOS and macOS arm64 builds passed. Signing, device installation and release archive not run.

## Image preparation prompt

Prepare this exact approved app icon as a production iOS/watchOS square icon texture. Preserve the exact red square brackets and white three-peak waveform, their shape, position, relative scale, proportions, colors, and the dark subtly shaded interior. ONLY remove the exterior white presentation background, drop shadow and rounded tile boundary by extending the near-black interior background to every edge and all four corners of the square canvas. Fully opaque, full bleed square, no rounded corners or inset tile, no border, no white margins, no transparency. Keep symbol in original central safe area, do NOT enlarge or redraw it creatively. No additions, no watch case, no typography. Single square high resolution PNG.
