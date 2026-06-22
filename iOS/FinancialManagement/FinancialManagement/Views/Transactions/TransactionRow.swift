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
    @State private var showDeleteConfirm = false
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
    /// Starts the spread flow. Offered only for un-spread expenses.
    var onCreateInstallment: (() -> Void)?
    /// Opens the edit form (web: the row's "Edit" menu item; the row tap also edits).
    var onEdit: (() -> Void)?
    /// Deletes the transaction after a confirmation (web: the "Delete" menu item).
    var onDelete: (() -> Void)?

    /// Eligible only for an expense that is not already spread.
    private var canCreateInstallment: Bool {
        transaction.type == .expense && !isSpread && onCreateInstallment != nil
    }

    private var isPending: Bool { transaction.status == .pending }

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(derived.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appForeground)
                        .lineLimit(1)
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

                chips
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(Self.dateFormatter.string(from: transaction.transactionDate))
                    .font(.caption)
                    .foregroundStyle(Color.appMutedForeground)
            }

            actionsMenu
        }
        .padding(.vertical, 4)
        .alert("Delete transaction?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete?() }
        } message: {
            Text("This permanently removes the transaction and updates the affected account balances. This can't be undone.")
        }
    }

    // MARK: - Actions menu (web: the row's trailing MoreVertical dropdown —
    // Edit / Create virtual installment / Delete)

    @ViewBuilder
    private var actionsMenu: some View {
        Menu {
            if let onEdit {
                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            }
            if canCreateInstallment {
                Button {
                    onCreateInstallment?()
                } label: {
                    Label("Create virtual installment", systemImage: "square.grid.2x2")
                }
            }
            if onDelete != nil {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            // Vertical dots to match web's MoreVertical (no vertical SF symbol).
            Image(systemName: "ellipsis")
                .font(.subheadline)
                .rotationEffect(.degrees(90))
                .foregroundStyle(Color.appMutedForeground)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

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
            .padding(.top, 2)
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

    private var subtitle: String? {
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

    private var formattedAmount: String {
        let formatted = abs(transaction.amount).asCurrency(code: appState.defaultCurrency)
        switch transaction.type {
        case .transfer:
            return formatted
        case .income:
            // Signed amounts allowed: a negative income reduces cash.
            return transaction.amount < 0 ? "-\(formatted)" : "+\(formatted)"
        case .expense:
            // Expenses reduce cash; a negative expense (refund) adds it back.
            return transaction.amount < 0 ? "+\(formatted)" : "-\(formatted)"
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
