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

// MARK: - Month page transition

extension View {
    func monthPageTransition(yearMonth: String, direction: Edge) -> some View {
        self
            .id(yearMonth)
            .transition(.push(from: direction))
    }
}
