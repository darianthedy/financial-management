import SwiftUI

struct MonthNavigator: View {
    let yearMonth: String
    var onPrevious: () -> Void
    var onNext: () -> Void

    var body: some View {
        // Mirrors web's month navigator: neutral (foreground) ghost chevrons
        // flanking a centered `text-sm font-medium` label with a fixed minimum
        // width so the month name doesn't shift the chevrons as it changes.
        HStack {
            Button {
                onPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body)
                    // HIG: 44×44pt minimum touch target. The glyph itself is far
                    // smaller, so size the tappable area explicitly.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(DateUtils.formatYearMonth(yearMonth))
                .font(.subheadline.weight(.medium))
                .frame(minWidth: 128)
                .contentTransition(.numericText())

            Spacer()

            Button {
                onNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(Color.appForeground)
        .padding(.horizontal)
    }
}

// MARK: - Month page transition

extension View {
    func monthPageTransition(yearMonth: String, direction: Edge) -> some View {
        modifier(MonthPageTransition(yearMonth: yearMonth, direction: direction))
    }
}

/// Slides the month-scoped content in the navigation direction, but honors
/// **Reduce Motion** by substituting a cross-fade for the horizontal push — a
/// sliding page transition is exactly the kind of large motion HIG asks apps to
/// suppress when the user has enabled the setting.
private struct MonthPageTransition: ViewModifier {
    let yearMonth: String
    let direction: Edge
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .id(yearMonth)
            .transition(reduceMotion ? .opacity : .push(from: direction))
    }
}
