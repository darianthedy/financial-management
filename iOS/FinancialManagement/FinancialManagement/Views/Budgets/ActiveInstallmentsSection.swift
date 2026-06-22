import SwiftUI

/// The Budgets page's "Active installments" list (§4.11 / §8.8): only the
/// installments that reserve allowance in the displayed month. Each entry shows
/// the source expense's title, total, month span, and budget-name chips; taps
/// link back to the source expense; a swipe **Cancel** deletes the header (which
/// cascades to its allocations so future budgets recover their allowance).
///
/// Mirrors web's `InstallmentList`
/// (`web/src/components/budgets/installment-list.tsx`): a "Active installments"
/// heading over bordered cards that stack the title, total, a "<span> · N
/// months" line, and muted budget-name chips.
struct ActiveInstallmentsSection: View {
    let installments: [ActiveInstallment]
    let currencyCode: String
    var onSelect: (Transaction) -> Void
    var onCancel: (ActiveInstallment) -> Void

    var body: some View {
        if !installments.isEmpty {
            Section {
                ForEach(installments) { item in
                    row(item)
                        .contentShape(Rectangle())
                        .onTapGesture { if let source = item.source { onSelect(source) } }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onCancel(item)
                            } label: {
                                Label("Cancel", systemImage: "xmark.bin")
                            }
                        }
                }
            } header: {
                Text("Active installments")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.appForeground)
                    .textCase(nil)
                    .padding(.leading, 16)
            }
        }
    }

    private func row(_ item: ActiveInstallment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.appForeground)
                        .lineLimit(1)
                    Text(item.installment.totalAmount.asCurrency(code: currencyCode))
                        .font(.subheadline)
                        .foregroundStyle(Color.appMutedForeground)
                }
                Spacer()
            }

            spanLine(item.installment)

            if !item.budgetNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(item.budgetNames, id: \.self) { name in
                            Text(name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.appMutedForeground)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color.appMuted, in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
    }

    /// "June 2026 · 3 months" for one month, "June 2026 – August 2026 · 3 months"
    /// for a span — the month range (muted) followed by the count (foreground),
    /// matching web's `spanLabel` plus the appended "· N months".
    private func spanLine(_ installment: BudgetInstallment) -> some View {
        let count = installment.months
        return (Text(span(installment))
            .font(.subheadline)
            .foregroundColor(Color.appMutedForeground)
            + Text(" · \(count) month\(count == 1 ? "" : "s")")
            .font(.subheadline)
            .foregroundColor(Color.appForeground))
    }

    private func span(_ installment: BudgetInstallment) -> String {
        let start = DateUtils.formatYearMonth(installment.startYearMonth)
        guard installment.months > 1 else { return start }
        let endMonth = DateUtils.navigate(installment.startYearMonth, by: installment.months - 1)
        let end = DateUtils.formatYearMonth(endMonth)
        return "\(start) – \(end)"
    }
}
