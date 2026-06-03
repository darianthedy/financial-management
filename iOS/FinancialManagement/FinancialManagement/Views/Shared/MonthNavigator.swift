import SwiftUI

struct MonthNavigator: View {
    let yearMonth: String
    var onPrevious: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack {
            Button {
                onPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            Text(DateUtils.formatYearMonth(yearMonth))
                .font(.headline)
                .contentTransition(.numericText())

            Spacer()

            Button {
                onNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
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
