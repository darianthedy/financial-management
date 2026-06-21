import SwiftUI

/// One budget for the selected month, read entirely from `v_budget_progress`:
/// net spent vs. effective amount (periodic + carry-in), a carry-in badge, an
/// info popover for the carry-in detail and note, and danger styling when
/// overspent. The "Reserved" line is a placeholder for installments (P11).
struct BudgetCard: View {
    let progress: BudgetProgress
    let currencyCode: String

    @State private var showingInfo = false

    /// Net spent against the effective amount, clamped to a drawable 0…1 range.
    private var fraction: Double {
        guard progress.effectiveAmount > 0 else { return progress.spent > 0 ? 1 : 0 }
        let value = Double(progress.spent) / Double(progress.effectiveAmount)
        return min(max(value, 0), 1)
    }

    private var isOverspent: Bool { progress.remaining < 0 }

    private var barColor: Color {
        if isOverspent { return .red }
        if fraction < 0.75 { return .green }
        if fraction < 0.9 { return .yellow }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            ProgressView(value: fraction)
                .tint(barColor)

            HStack {
                Text("\(progress.spent.asCurrency(code: currencyCode)) of \(progress.effectiveAmount.asCurrency(code: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if isOverspent {
                    Text("\((-progress.remaining).asCurrency(code: currencyCode)) over")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                } else {
                    Text("\(progress.remaining.asCurrency(code: currencyCode)) left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // P11 placeholder: installment "Reserved" line lands here once
            // budget_installment_allocations feed `reserved` into the card.
        }
        .padding(.vertical, 4)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(progress.budgetName)
                .font(.headline)

            if progress.carryOverAmount != 0 {
                carryInBadge
            }

            if progress.carryOverAmount != 0 || (progress.description?.isEmpty == false) {
                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingInfo) { infoPopover }
            }

            Spacer()

            Text(progress.effectiveAmount.asCurrency(code: currencyCode))
                .font(.subheadline.bold())
        }
    }

    private var carryInBadge: some View {
        let positive = progress.carryOverAmount > 0
        let text = "\(positive ? "+" : "")\(progress.carryOverAmount.asCurrency(code: currencyCode))"
        return Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((positive ? Color.green : Color.red).opacity(0.15))
            .foregroundStyle(positive ? Color.green : Color.red)
            .clipShape(Capsule())
    }

    private var infoPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            if progress.carryOverAmount != 0 {
                let positive = progress.carryOverAmount > 0
                Text("\(positive ? "+" : "")\(progress.carryOverAmount.asCurrency(code: currencyCode)) \(positive ? "carried over" : "overspent")")
                    .font(.subheadline)
            }
            if let note = progress.description, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .presentationCompactAdaptation(.popover)
    }
}
