import SwiftUI

/// The Budgets page's "Active installments" list (§4.11 / §8.8): only the
/// installments that reserve allowance in the displayed month. Each entry shows
/// the source expense's title, total, month span, and budget-name chips; taps
/// link back to the source expense; a swipe **Cancel** deletes the header (which
/// cascades to its allocations so future budgets recover their allowance).
struct ActiveInstallmentsSection: View {
    let installments: [ActiveInstallment]
    let currencyCode: String
    var onSelect: (Transaction) -> Void
    var onCancel: (ActiveInstallment) -> Void

    var body: some View {
        if !installments.isEmpty {
            Section("Active Installments") {
                ForEach(installments) { item in
                    row(item)
                        .contentShape(Rectangle())
                        .onTapGesture { if let source = item.source { onSelect(source) } }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onCancel(item)
                            } label: {
                                Label("Cancel", systemImage: "xmark.bin")
                            }
                        }
                }
            }
        }
    }

    private func row(_ item: ActiveInstallment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Text(item.installment.totalAmount.asCurrency(code: currencyCode))
                    .font(.subheadline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(spanLabel(item.installment))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !item.budgetNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(item.budgetNames, id: \.self) { name in
                            Text(name)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// "Jun 2026 · 3 months" — the span from the header's start month and count.
    private func spanLabel(_ installment: BudgetInstallment) -> String {
        let start = DateUtils.formatYearMonth(installment.startYearMonth)
        let count = installment.months
        return "\(start) · \(count) month\(count == 1 ? "" : "s")"
    }
}
