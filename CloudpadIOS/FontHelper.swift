import SwiftUI

// MARK: – Caveat font (used for the "cloudpad" wordmark, matching the web)

extension Font {
    static func caveat(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Caveat", size: size).weight(weight)
    }
}

// MARK: – Inter font helpers
//
// InterVariable.ttf ships as a single variable font that covers all weights.
// The PostScript family name exposed to UIKit/SwiftUI is "Inter".

extension Font {
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    // Semantic aliases matching the web app's type scale
    static func interCaption(_ weight: Font.Weight = .regular)    -> Font { inter(11, weight: weight) }
    static func interSmall(_ weight: Font.Weight = .regular)      -> Font { inter(12, weight: weight) }
    static func interBody(_ weight: Font.Weight = .regular)       -> Font { inter(15, weight: weight) }
    static func interSubhead(_ weight: Font.Weight = .regular)    -> Font { inter(13, weight: weight) }
    static func interTitle(_ weight: Font.Weight = .semibold)     -> Font { inter(17, weight: weight) }
    static func interHeadline(_ weight: Font.Weight = .bold)      -> Font { inter(20, weight: weight) }
}
