import SwiftUI

/// One transaction, read-only, laid out like a Contacts card: the account
/// avatar, amount and title on top, a row of round actions, then the fields
/// in rounded cards, and Delete at the bottom.
///
/// **Edit** turns the same screen into the form in place (Cancel / Save on
/// the bar); finishing either way returns to the card. The form edits a draft
/// from `TransactionEditorDrafts`, so a fold mid-edit reopens it still editing.
/// Shown in the Transactions detail column on regular width, pushed elsewhere.
struct TransactionDetailView: View {
    @Environment(AppState.self) private var appState

    let presentation: TransactionPresentation
    /// The draft to edit, started on first use (see `TransactionEditorDrafts`).
    let draft: () -> TransactionFormViewModel
    /// Reports unsaved edits, so the list can confirm before switching rows.
    @Binding var isDirty: Bool
    /// Reloads the list after a save.
    var onSaved: () async -> Void
    /// The editor closed (saved or cancelled): drop the draft.
    var onEditingEnded: () -> Void
    /// Confirm / dismiss a pending transaction.
    var onSetStatus: ((TransactionStatus) async -> Void)?
    /// Starts the "spread across budgets" flow.
    var onCreateInstallment: (() -> Void)?
    /// Deletes the transaction and closes this screen.
    var onDelete: () async -> Void

    @State private var editor: TransactionFormViewModel?
    @State private var confirmingDelete = false

    init(
        presentation: TransactionPresentation,
        startsEditing: Bool = false,
        draft: @escaping () -> TransactionFormViewModel,
        isDirty: Binding<Bool>,
        onSaved: @escaping () async -> Void,
        onEditingEnded: @escaping () -> Void,
        onSetStatus: ((TransactionStatus) async -> Void)? = nil,
        onCreateInstallment: (() -> Void)? = nil,
        onDelete: @escaping () async -> Void
    ) {
        self.presentation = presentation
        self.draft = draft
        _isDirty = isDirty
        self.onSaved = onSaved
        self.onEditingEnded = onEditingEnded
        self.onSetStatus = onSetStatus
        self.onCreateInstallment = onCreateInstallment
        self.onDelete = onDelete
        _editor = State(initialValue: startsEditing ? draft() : nil)
    }

    private var transaction: Transaction { presentation.transaction }

    var body: some View {
        ZStack {
            if let editor {
                TransactionFormView(
                    model: editor,
                    onSaved: onSaved,
                    onClose: endEditing,
                    isDirty: $isDirty
                )
                .layoutProbe("transactionDetail.editor")
                .transition(.opacity)
            } else {
                card
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: editor == nil)
    }

    private func startEditing() {
        editor = draft()
    }

    private func endEditing() {
        editor = nil
        isDirty = false
        onEditingEnded()
    }

    // MARK: - Card

    private var card: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                actions
                fieldsCard
                if hasLinks { linksCard }
                if !presentation.tags.isEmpty { tagsCard }
                if let note { noteCard(note) }
                deleteCard
            }
            .frame(maxWidth: ReadableWidth.maximumContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", action: startEditing)
            }
        }
        .alert("Delete transaction?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await onDelete() }
            }
        } message: {
            Text("This permanently removes the transaction and updates the affected account balances. This can't be undone.")
        }
        .layoutProbe("transactionDetail")
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 8) {
            heroAvatar
                .padding(.bottom, 8)
            AmountColumnView(
                minorUnits: transaction.amount,
                sign: presentation.amountSign,
                currencyCode: appState.defaultCurrency,
                alwaysWhole: true
            )
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(presentation.amountColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .layoutProbe("transactionDetail.amount")

            Text(presentation.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.appForeground)
                .multilineTextAlignment(.center)
            if let accountLine = presentation.accountLine {
                Text(accountLine)
                    .font(.subheadline)
                    .foregroundStyle(Color.appMutedForeground)
                    .multilineTextAlignment(.center)
            }
            if presentation.isPending {
                Label("Pending", systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appWarning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appWarning.opacity(0.14), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var heroAvatar: some View {
        if let account = presentation.account {
            AccountAvatar(imageUrl: account.imageUrl, accountType: account.type, size: 96)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: presentation.typeIcon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(presentation.amountColor)
                        .padding(3)
                        .background(Circle().fill(Color.appBackground))
                }
        } else {
            Image(systemName: presentation.typeIcon)
                .font(.system(size: 64))
                .foregroundStyle(presentation.amountColor)
                .frame(width: 96, height: 96)
        }
    }

    // MARK: Actions (Share is always there, so the row never empties)

    private var actions: some View {
        HStack(alignment: .top, spacing: 12) {
            if presentation.isPending, let onSetStatus {
                actionButton("Confirm", systemImage: "checkmark", tint: .appSuccess) {
                    Task { await onSetStatus(.confirmed) }
                }
                actionButton("Dismiss", systemImage: "xmark", tint: .appWarning) {
                    Task { await onSetStatus(.dismissed) }
                }
            }
            if presentation.canCreateInstallment, let onCreateInstallment {
                actionButton("Spread", systemImage: "square.grid.2x2", tint: .appPrimary, action: onCreateInstallment)
            }
            ShareLink(item: shareText) {
                actionLabel("Share", systemImage: "square.and.arrow.up", tint: .appPrimary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(
        _ title: String, systemImage: String, tint: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionLabel(title, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(_ title: String, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.appCard))
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.appForeground)
        }
        .frame(minWidth: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    /// "Food · -Rp 50.000 · Nov 4, 2026 · BCA", for Share.
    private var shareText: String {
        let amount = CurrencyUtils.format(
            abs(transaction.amount), currency: appState.defaultCurrency, decimalPlaces: appState.decimalPlaces
        )
        var parts = [presentation.title, presentation.amountSign + amount, Self.dateFormatter.string(from: transaction.transactionDate)]
        if let accountLine = presentation.accountLine { parts.append(accountLine) }
        if let note { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    // MARK: Fields

    private var fieldsCard: some View {
        CardSection {
            field("type", presentation.typeName)
            field("date", Self.dateFormatter.string(from: transaction.transactionDate))
            if transaction.type == .transfer {
                field("from", presentation.account?.name ?? "—")
                field("to", presentation.transferAccountName ?? "—")
            } else {
                field("account", presentation.account?.name ?? "—")
            }
        }
    }

    private var hasLinks: Bool {
        (presentation.budgetName != nil && transaction.type != .transfer)
            || presentation.category != nil
            || presentation.fixedExpenseName != nil
    }

    private var linksCard: some View {
        CardSection {
            if transaction.type != .transfer, let budgetName = presentation.budgetName {
                field("budget", budgetName)
            }
            if let category = presentation.category {
                field("category", category.name, dot: category.color.flatMap { Color(hex: $0) })
            }
            if let fixed = presentation.fixedExpenseName {
                field("fixed expense", fixed)
            }
        }
    }

    private var tagsCard: some View {
        CardSection {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("tags")
                FlowLayout(spacing: 6) {
                    ForEach(presentation.tags) { tag in
                        Label(tag.name, systemImage: "tag")
                            .font(.subheadline)
                            .foregroundStyle(Color.appForeground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.appMuted, in: Capsule())
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    /// The description, unless it already is the title.
    private var note: String? {
        guard let description = presentation.description, !description.isEmpty,
              !presentation.derived.titleIsDescription else { return nil }
        return description
    }

    private func noteCard(_ note: String) -> some View {
        CardSection {
            field("description", note)
        }
    }

    private var deleteCard: some View {
        CardSection {
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Text("Delete Transaction")
                    .foregroundStyle(Color.appDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// A Contacts field: a small label over its value.
    private func field(_ label: String, _ value: String, dot: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            fieldLabel(label)
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 10, height: 10)
                }
                Text(value)
                    .font(.body)
                    .foregroundStyle(Color.appForeground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func fieldLabel(_ label: String) -> some View {
        Text(label)
            .font(.subheadline)
            .foregroundStyle(Color.appMutedForeground)
    }

    /// "Wednesday, Nov 4, 2026".
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()
}

/// A rounded card of rows with hairlines between them, as in Contacts.
private struct CardSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider() }
                    row
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
