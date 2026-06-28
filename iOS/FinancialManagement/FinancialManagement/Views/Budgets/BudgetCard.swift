import SwiftUI

/// One budget for the selected month, read entirely from `v_budget_progress`:
/// net spent vs. effective amount (periodic + carry-in), an info popover for the
/// carry-in detail and note, and danger styling when overspent. A "reserved"
/// line shows virtual-installment reservations (P1).
///
/// Mirrors web's `BudgetCard` (`web/src/components/budgets/budget-card.tsx`): a
/// bordered card with the name + info popover, a rounded progress bar
/// (primary fill, danger when overspent), a "spent of X" / remaining row, and an
/// optional reserved line.
struct BudgetCard: View {
    let progress: BudgetProgress
    let currencyCode: String
    /// Opens the edit form (web: the card's trailing "Edit" menu item).
    var onEdit: (() -> Void)?
    /// Requests removal of this month's budget row (web: "Remove"). The owning list
    /// presents the shared confirmation alert, so the card's ⋮ menu and the list's
    /// swipe action go through the same guard.
    var onRemove: (() -> Void)?

    @State private var showingInfo = false

    /// Effective budget is periodic + carry-in minus installment reservations —
    /// what is actually available to spend this month. Both the bar and the
    /// "spent of X" label use this figure (web: `effective_amount - reserved`).
    private var effectiveBudget: Int64 { progress.effectiveAmount - progress.reserved }

    /// Net spent against the effective budget, clamped to a drawable 0…1 range.
    private var fraction: Double {
        guard effectiveBudget > 0 else { return progress.spent > 0 ? 1 : 0 }
        let value = Double(progress.spent) / Double(effectiveBudget)
        return min(max(value, 0), 1)
    }

    private var isOverspent: Bool { progress.remaining < 0 }

    /// web uses two states only: primary under budget, danger when overspent.
    private var barColor: Color { isOverspent ? .appDanger : .appPrimary }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            progressBar

            HStack {
                Text("\(progress.spent.asCurrency(code: currencyCode)) of \(effectiveBudget.asCurrency(code: currencyCode))")
                    .font(.subheadline)
                    .foregroundStyle(Color.appMutedForeground)

                Spacer()

                if isOverspent {
                    Text("\((-progress.remaining).asCurrency(code: currencyCode)) over")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appDanger)
                } else {
                    Text("\(progress.remaining.asCurrency(code: currencyCode)) left")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appForeground)
                }
            }

            // Virtual-installment reservations (P1): a distinct, muted line
            // separate from the carry-over label (which lives in the info
            // popover). Already netted into `remaining` by v_budget_progress.
            if progress.reserved > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                    Text("−\(progress.reserved.asCurrency(code: currencyCode)) reserved for installments")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(Color.appMutedForeground)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
    }

    // MARK: - Actions menu (web: the card's trailing MoreVertical dropdown —
    // Edit / Remove)

    @ViewBuilder
    private var actionsMenu: some View {
        Menu {
            if onEdit != nil {
                Button { onEdit?() } label: { Label("Edit", systemImage: "pencil") }
            }
            if let onRemove {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        } label: {
            // Vertical dots to match web's MoreVertical (no vertical SF symbol).
            Image(systemName: "ellipsis")
                .font(.subheadline)
                .rotationEffect(.degrees(90))
                .foregroundStyle(Color.appMutedForeground)
                // 44×44 hit area (HIG minimum). The glyph stays visually small;
                // the frame just enlarges the tappable region.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 8pt rounded track (muted) with a rounded fill, matching web's
    /// `h-2 rounded-full bg-muted` track and `rounded-full` fill.
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appMuted)
                Capsule()
                    .fill(barColor)
                    .frame(width: max(0, geo.size.width * fraction))
            }
        }
        .frame(height: 8)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(progress.budgetName)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.appForeground)
                .lineLimit(1)
                .truncationMode(.tail)

            if progress.carryOverAmount != 0 || (progress.description?.isEmpty == false) {
                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.appMutedForeground)
                        // 44×44 hit area (HIG minimum), matching the ⋮ menu. The
                        // glyph stays visually small; the frame only enlarges the
                        // tappable region and the popover still anchors to it.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingInfo,
                         attachmentAnchor: .rect(.bounds),
                         arrowEdge: .top) { infoPopover }
            }

            Spacer()

            if onEdit != nil || onRemove != nil {
                actionsMenu
            }
        }
    }

    private var infoPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            if progress.carryOverAmount != 0 {
                let positive = progress.carryOverAmount > 0
                Text(positive
                    ? "+\(progress.carryOverAmount.asCurrency(code: currencyCode)) carried over"
                    : "\(progress.carryOverAmount.asCurrency(code: currencyCode)) overspent")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(positive ? Color.appSuccess : Color.appDanger)
            }
            if let note = progress.description, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Color.appMutedForeground)
            }
        }
        .padding()
        // Cap width so the popover stays compact on iPhone; on iPad the
        // window width is already constrained by the native popover chrome.
        .frame(minWidth: 180, maxWidth: 280)
        // Prevent degradation to a full-screen sheet in compact size classes
        // (iPhone). Requires iOS 16.4+; below that the system falls back to
        // a sheet automatically, but this project targets iOS 26.1+.
        .presentationCompactAdaptation(.popover)
    }
}
