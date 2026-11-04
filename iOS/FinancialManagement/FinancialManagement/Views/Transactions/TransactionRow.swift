import SwiftUI

/// A single transaction row, aligned to the web row
/// (`web/src/components/transactions/transaction-row.tsx` +
/// `transaction-display.tsx`): a leading account avatar with a direction badge,
/// a title that follows the web precedence (budget → fixed expense → category →
/// description → type), an optional description subtitle, a wrapping chip row
/// (fixed expense / transfer destination / category / tags), and a right-aligned
/// amount (success/danger/foreground per type) over the date.
struct TransactionRow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.isSplitListColumn) private var isSplitListColumn
    let transaction: Transaction
    /// The transaction's source account, used for the avatar. Falls back to a
    /// type glyph when unavailable.
    var account: Account?
    /// The single linked category (used for the title and/or a chip).
    var category: Category?
    /// The transfer destination account's name (the "→ name" chip on transfers).
    var transferAccountName: String?
    /// Tags attached to the row, rendered as chips.
    var tags: [Tag] = []
    /// Linked budget's name — the top of the title precedence.
    var budgetName: String?
    /// Linked fixed expense's name — title fallback and the "Fixed" chip.
    var fixedExpenseName: String?
    /// True when this expense has been spread across budgets (P1 installments) —
    /// drives the grid indicator and hides the "Create virtual installment" action.
    var isSpread = false
    /// Show the date beneath the amount. Off when the row sits under a date group
    /// header (the transactions list) that already carries the date; on for
    /// ungrouped lists. Mirrors the web row's `showDate` prop.
    var showDate = true
    /// The widest number body across the surrounding list, so this row's amount
    /// aligns its symbol/digits with the others (see `AmountColumnView`). Omit for
    /// a standalone row.
    var widestNumber: String?
    /// Starts the spread flow. Offered only for un-spread expenses.
    var onCreateInstallment: (() -> Void)?
    /// Opens the edit form (web: the row's "Edit" menu item; the row tap also edits).
    var onEdit: (() -> Void)?
    /// Requests deletion (web: the "Delete" menu item). The owning list presents the
    /// shared confirmation alert and performs the delete, so the row's long-press
    /// menu and the list's swipe action go through the same guard.
    var onDelete: (() -> Void)?

    /// Eligible only for an expense that is not already spread.
    private var canCreateInstallment: Bool {
        transaction.type == .expense && !isSpread && onCreateInstallment != nil
    }

    private var isPending: Bool { transaction.status == .pending }

    /// The title's floor in the one-line row: narrow enough that avatar,
    /// title and an aligned "-Rp 2.147.230" fit a ~333 pt split column.
    private static let minimumTitleWidth: CGFloat = 72

    var body: some View {
        // Always one line, with the amount in the list-aligned column (symbol
        // left, digits right, sized to the widest amount). The amount never
        // truncates on either display; the title and subtitle give way.
        HStack(spacing: 12) {
            avatar
            titleColumn
                .frame(minWidth: Self.minimumTitleWidth, maxWidth: .infinity, alignment: .leading)
            amountColumn(widestNumber: widestNumber)
                .layoutPriority(1)
        }
        .padding(.vertical, 6)
        // Long-press (or secondary click) lifts a preview of the transaction
        // with its actions above it, as Notes does; tap still edits and the
        // list's swipe still deletes.
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            actions
        } preview: {
            previewCard
        }
    }

    private var titleColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(derived.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appForeground)
                        .lineLimit(1)
                        .layoutProbe("transactionRow.title.\(derived.title)")
                    if isPending { pendingBadge }
                    if isSpread {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.appPrimary)
                            .accessibilityLabel("Spread across budgets")
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.appMutedForeground)
                        .lineLimit(1)
                }

                // The split list column sits beside the detail, which shows
                // everything, so its rows stay at two lines: no chip row.
                if !isSplitListColumn {
                    chips
                }
        }
    }

    private func amountColumn(widestNumber: String?) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            AmountColumnView(
                minorUnits: transaction.amount,
                sign: amountSign,
                currencyCode: appState.defaultCurrency,
                widestNumber: widestNumber,
                alwaysWhole: true
            )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .layoutProbe("transactionRow.amount.\(derived.title)")
            if showDate {
                Text(Self.dateFormatter.string(from: transaction.transactionDate))
                    .font(.caption)
                    .foregroundStyle(Color.appMutedForeground)
            }
        }
    }

    // MARK: - Long-press actions (web: the row's MoreVertical dropdown —
    // Edit / Create virtual installment / Delete)

    /// A control group renders as the menu's top row of icons (Notes' Share /
    /// Move / Delete).
    @ViewBuilder
    private var actions: some View {
        ControlGroup {
            if let onEdit {
                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            }
            if canCreateInstallment {
                Button {
                    onCreateInstallment?()
                } label: {
                    Label("Virtual Installment", systemImage: "square.grid.2x2")
                }
            }
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Long-press preview

    /// The lifted card: the full picture of the transaction that the row
    /// itself trims (account, amount, description, date, links, chips).
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(derived.title)
                        .font(.headline)
                        .foregroundStyle(Color.appForeground)
                        .lineLimit(2)
                    if let accountLine {
                        Text(accountLine)
                            .font(.subheadline)
                            .foregroundStyle(Color.appMutedForeground)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if isPending { pendingBadge }
            }

            AmountColumnView(
                minorUnits: transaction.amount,
                sign: amountSign,
                currencyCode: appState.defaultCurrency,
                alwaysWhole: true
            )
            .font(.title.weight(.bold))
            .foregroundStyle(amountColor)

            if let description = transaction.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(3)
            }

            VStack(alignment: .leading, spacing: 6) {
                previewDetail(Self.previewDateFormatter.string(from: transaction.transactionDate),
                              systemImage: "calendar")
                if let budgetName, transaction.type != .transfer {
                    previewDetail(budgetName, systemImage: "chart.pie")
                }
                if let fixedExpenseName {
                    previewDetail(fixedExpenseName, systemImage: "receipt")
                }
                if let category {
                    previewDetail(category.name, systemImage: "folder")
                }
            }

            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags) { tag in
                        chip(tag.name, systemImage: "tag",
                             fill: Color.appCard,
                             foreground: Color.appMutedForeground,
                             border: Color.appBorder)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
        .background(Color.appCard)
    }

    /// "BCA → BCA VISA SQ Infinite" for a transfer, else the account's name.
    private var accountLine: String? {
        guard let account else { return transferAccountName.map { "→ \($0)" } }
        if transaction.type == .transfer, let transferAccountName {
            return "\(account.name) → \(transferAccountName)"
        }
        return account.name
    }

    private func previewDetail(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text).lineLimit(1)
        } icon: {
            Image(systemName: systemImage).frame(width: 18)
        }
        .font(.subheadline)
        .foregroundStyle(Color.appMutedForeground)
    }

    /// "Wednesday, Nov 4, 2026".
    private static let previewDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    // MARK: - Avatar

    @ViewBuilder
    private var avatar: some View {
        if let account {
            AccountAvatar(imageUrl: account.imageUrl, accountType: account.type, size: 40)
                .overlay(alignment: .bottomTrailing) { typeBadge }
        } else {
            Image(systemName: typeIcon)
                .font(.title3)
                .foregroundStyle(amountColor)
                .frame(width: 40)
        }
    }

    private var typeBadge: some View {
        Image(systemName: typeIcon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(amountColor)
            .padding(2)
            .background(Circle().fill(Color.appCard))
            .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 1))
    }

    // MARK: - Pending badge (web: warning-tinted pill with a clock)

    private var pendingBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
            Text("Pending")
        }
        .font(.system(size: 10, weight: .semibold))
        .textCase(.uppercase)
        .foregroundStyle(Color.appWarning)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.appWarning.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.appWarning.opacity(0.4), lineWidth: 1))
        .fixedSize()
    }

    // MARK: - Chips (web: TransactionChips)

    @ViewBuilder
    private var chips: some View {
        let dest = transaction.type == .transfer ? transferAccountName : nil
        // Show the category unless it was promoted to the title.
        let chipCategory = derived.usedCategory ? nil : category
        // Show the fixed expense unless it was promoted to the title.
        let chipFixed = derived.usedFixed ? nil : fixedExpenseName

        if dest != nil || chipCategory != nil || chipFixed != nil || !tags.isEmpty {
            FlowLayout(spacing: 6) {
                if let chipFixed {
                    chip(chipFixed, systemImage: "receipt",
                         fill: Color.appPrimary.opacity(0.12),
                         foreground: Color.appPrimary,
                         border: Color.appBorder)
                }
                if let dest {
                    chip("→ \(dest)", fill: Color.appCard,
                         foreground: Color.appForeground, border: Color.appBorder)
                }
                if let chipCategory {
                    categoryChip(chipCategory)
                }
                ForEach(tags) { tag in
                    chip(tag.name, systemImage: "tag",
                         fill: Color.appCard,
                         foreground: Color.appMutedForeground,
                         border: Color.appBorder)
                }
            }
            .padding(.top, 4)
        }
    }

    /// The category chip: tinted with the category's own color when set
    /// (`{color}1a` fill + `color` text on web), otherwise neutral/muted.
    @ViewBuilder
    private func categoryChip(_ category: Category) -> some View {
        if let hex = category.color, let color = Color(hex: hex) {
            chip(category.name, fill: color.opacity(0.1), foreground: color, border: .clear)
        } else {
            chip(category.name, fill: Color.appMuted,
                 foreground: Color.appMutedForeground, border: Color.appBorder)
        }
    }

    /// A pill chip mirroring web's `rounded-full border px-2 py-0.5 text-xs
    /// font-medium`, optionally with a leading SF Symbol.
    private func chip(_ text: String, systemImage: String? = nil,
                      fill: Color, foreground: Color, border: Color) -> some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 9))
            }
            Text(text).lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(fill, in: Capsule())
        .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }

    // MARK: - Title derivation (web: deriveTitle)

    private struct DerivedTitle {
        let title: String
        /// The category was promoted to the title, so drop its chip.
        let usedCategory: Bool
        /// The fixed expense was promoted to the title, so drop its chip.
        let usedFixed: Bool
        /// The description became the title, so don't repeat it as a subtitle.
        let titleIsDescription: Bool
    }

    /// Title precedence: budget (non-transfer) → fixed expense → category →
    /// description → the type word.
    private var derived: DerivedTitle {
        if let budgetName, transaction.type != .transfer {
            return DerivedTitle(title: budgetName, usedCategory: false, usedFixed: false, titleIsDescription: false)
        }
        if let fixedExpenseName {
            return DerivedTitle(title: fixedExpenseName, usedCategory: false, usedFixed: true, titleIsDescription: false)
        }
        if let category {
            return DerivedTitle(title: category.name, usedCategory: true, usedFixed: false, titleIsDescription: false)
        }
        if let description = transaction.description, !description.isEmpty {
            return DerivedTitle(title: description, usedCategory: false, usedFixed: false, titleIsDescription: true)
        }
        return DerivedTitle(title: transaction.type.rawValue.capitalized,
                            usedCategory: false, usedFixed: false, titleIsDescription: false)
    }

    /// The second line. In the split list column a transfer shows its
    /// destination there (plain text, not a chip) instead of the description.
    private var subtitle: String? {
        if isSplitListColumn, transaction.type == .transfer, let transferAccountName {
            return "→ \(transferAccountName)"
        }
        guard let description = transaction.description,
              !description.isEmpty, !derived.titleIsDescription else { return nil }
        return description
    }

    // MARK: - Type styling

    private var typeIcon: String {
        switch transaction.type {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    /// Amount/direction color, matching web `amountColor`: income → success,
    /// expense → danger, transfer → foreground.
    private var amountColor: Color {
        switch transaction.type {
        case .income: return .appSuccess
        case .expense: return .appDanger
        case .transfer: return .appForeground
        }
    }

    /// The leading sign for the amount (the magnitude is rendered by
    /// `AmountColumnView`). Transfers are unsigned; income is `+` (a negative
    /// income reduces cash, so `-`); an expense is `-` (a negative expense — a
    /// refund — adds cash back, so `+`).
    private var amountSign: String {
        switch transaction.type {
        case .transfer:
            return ""
        case .income:
            return transaction.amount < 0 ? "-" : "+"
        case .expense:
            return transaction.amount < 0 ? "+" : "-"
        }
    }

    /// Web date format: "MMM d, yyyy" (e.g. "Jun 3, 2026").
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
}
