# lisan icon

The icon combines rounded audio waveform bars with a tilted planetary ring. The full-color artwork uses lisan’s burnt orange and cream palette. The menu bar uses a matching native template drawing so macOS can display it correctly on light and dark backgrounds.

- Source artwork: [lisan-icon.png](../Sources/VoiceBar/Brand/lisan-icon.png).
- Menu bar drawing and artwork loading: [BrandIcon.swift](../Sources/VoiceBar/BrandIcon.swift).
- The build script creates the ten standard macOS icon sizes and packages `lisan.icns` automatically. No extra image library is needed.
- The artwork is bundled for both SwiftPM previews and installed apps. Packaged apps load their own artwork directly rather than relying on paths on the developer’s computer.

## Generation

Created with the built-in image generation tool, with a transparent background. The generated source is kept unchanged; Apple’s `sips` and `iconutil` tools resize and package it for macOS. The tiny menu bar version is a native drawing based on the seven bars in the final artwork.

Prompt:

> Use case: logo-brand. Asset type: production macOS application icon for lisan, a minimal local voice dictation app inspired by Dune. Create a beautiful crisp, minimal, distinctive square macOS icon, 1024 by 1024 composition. Centered burnt-orange rounded-square tile (#C65D32), taking up about 84% of the canvas with generous transparent outer margins and a soft subtle edge shadow. In the center: a cream-white (#FFF4E6) Saturn-like planet made from exactly nine vertical rounded audio waveform bars, with the outer bars short and the middle bars tallest, so together they form a clean circular globe silhouette. A single thin elegant elliptical orbital ring crosses the waveform globe diagonally, rising from lower-left to upper-right, with a convincing front/back overlap and crisp negative-space separation. The waveform IS the planet body; do not put a waveform inside an otherwise solid planet. Bold balanced graphic geometry, vector-like edge quality, sophisticated Mac utility aesthetic, very restrained warm gradient on the orange tile, mostly flat cream mark with no material texture. The whole planet-and-ring symbol is large and centered with comfortable breathing room. It must read as a waveform planet at small sizes. Exactly one icon, no variations, no presentation board, no text or letters or stars or sparkles or microphone, no mockup, no scenery. Actual transparent pixels outside the rounded tile.

## Preview

Run the UI preview commands in the [developer guide](../DEVELOPMENT.md). The exported `brand.png` shows the actual Settings header and the menu bar mark on light and dark backgrounds.
