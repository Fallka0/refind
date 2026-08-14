# Bundled fonts

Both families are redistributed here under the **SIL Open Font License, Version 1.1**,
which permits bundling them inside an application.

| File | Family | Source |
|---|---|---|
| `InstrumentSerif-Regular.ttf` | Instrument Serif | [Google Fonts](https://fonts.google.com/specimen/Instrument+Serif) |
| `Archivo-Regular.ttf` | Archivo | [Google Fonts](https://fonts.google.com/specimen/Archivo) |
| `Archivo-Medium.ttf` | Archivo | [Google Fonts](https://fonts.google.com/specimen/Archivo) |
| `Archivo-SemiBold.ttf` | Archivo | [Google Fonts](https://fonts.google.com/specimen/Archivo) |

The full licence text ships with each family on Google Fonts and in the
[google/fonts](https://github.com/google/fonts) repository — copy the `OFL.txt`
for each family in here before shipping to the App Store.

The files are registered in `Config/Info.plist` under `UIAppFonts`. Their internal
PostScript names must keep matching the names in `DesignSystem.swift`
(`InstrumentSerif-Regular`, `Archivo-Regular`, `Archivo-Medium`, `Archivo-SemiBold`)
or SwiftUI silently falls back to the system font.
