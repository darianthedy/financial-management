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
            }

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
            }
        }
        .foregroundStyle(Color.appForeground)
        .padding(.horizontal)
    }
}

// MARK: - Swipe-to-navigate modifier

private struct SwipeToNavigateMonthModifier: ViewModifier {
    var onPrevious: () -> Void
    var onNext: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 50, coordinateSpace: .local)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        guard abs(horizontal) > abs(vertical) * 1.5 else { return }
                        if horizontal > 0 {
                            onPrevious()
                        } else {
                            onNext()
                        }
                    }
            )
    }
}

extension View {
    func swipeToNavigateMonth(onPrevious: @escaping () -> Void, onNext: @escaping () -> Void) -> some View {
        modifier(SwipeToNavigateMonthModifier(onPrevious: onPrevious, onNext: onNext))
    }

    func monthPageTransition(yearMonth: String, direction: Edge) -> some View {
        self
            .id(yearMonth)
            .transition(.push(from: direction))
    }
}
