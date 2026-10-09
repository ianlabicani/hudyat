# Hudyat logo C

The user selected **C — Flare at the horizon** from the supplied Logo
directions mockup. Its 96 × 96 geometry is preserved in
`tool/generate_brand_assets.swift`, which generates the SVG exports,
transparent Flutter mark, legacy launcher PNGs and native Android vectors.

From the repository root on macOS, regenerate with:

```sh
swift tool/generate_brand_assets.swift
```

Light artwork uses ink `#1B1B19` and a rust flare `#B93A0B`.
Dark artwork uses pale rays `#F2F1EC` and a bright orange flare `#F26A2E`
on charcoal `#1B1B19`. The launcher uses the dark treatment. Legacy icons
preserve the mockup's rounded tile; adaptive icons let Android apply its mask.
The adaptive foreground fits inside the 66dp safe circle, and its monochrome
variant lets Android tint themed icons.

Only `hudyat_mark_c.png` and its resolution variants are bundled in Flutter.
The widget uses native color resources for light and dark mode. Android's
launch screen uses the dark mark; scam alerts retain their warning triangle.
The `source/` folder is reusable source artwork, and `build/brand/` contains
local visual previews.

Sizing references: [Android adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
and [Android splash screens](https://developer.android.com/develop/ui/views/launch/splash-screen).
