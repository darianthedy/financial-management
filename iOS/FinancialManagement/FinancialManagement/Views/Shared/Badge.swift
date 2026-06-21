import SwiftUI

/// Pill badge mirroring web's shared `Badge` (`web/src/components/ui/misc.tsx`):
/// a fully-rounded chip with a 1pt border, muted fill and `xs`/medium
/// muted-foreground text. Used on account cards (type + "Off dashboard") so the
/// chips read identically to web.
struct Badge: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.appMutedForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.appMuted, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.appBorder, lineWidth: 1))
    }
}
