//
//  FontLoader.swift
//  refind
//
//  The fonts are bundled and registered through Info.plist's UIAppFonts, so
//  nothing has to be loaded at runtime. What this does is fail loudly in debug
//  if a face did not resolve — otherwise SwiftUI silently substitutes San
//  Francisco and the whole design reads subtly wrong with no error anywhere.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum FontLoader {

    static let required: [String] = [
        RF.Font_.serif,
        RF.Font_.sans,
        RF.Font_.sansMedium,
        RF.Font_.sansSemibold
    ]

    /// Names that did not resolve to a real face.
    static var missing: [String] {
        #if canImport(UIKit)
        required.filter { UIFont(name: $0, size: 12) == nil }
        #else
        []
        #endif
    }

    static func verify() {
        let missing = self.missing
        guard !missing.isEmpty else { return }
        assertionFailure(
            "refind: these fonts did not load — \(missing.joined(separator: ", ")). "
            + "Check Resources/Fonts and the UIAppFonts array in Info.plist."
        )
    }
}
