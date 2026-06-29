import SwiftUI

struct ScheduledListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ScheduledTransactionViewModel()
    @State private var editingPending: Transaction?
    @State private var showingForm = false
    @State private var editingScheduled: EnrichedScheduledTransaction?
    /// The schedule awaiting delete confirmation (HIG: confirm permanent deletes).
    @State private var pendingDelete: EnrichedScheduledTransaction?

    var body: some View {
        List {
            if !viewModel.pendingTransactions.isEmpty {
                Section("Pending") {
                    ForEach(viewModel.pendingTransactions) { pending in
                        PendingTransactionRow(
                            pending: pending,
                            budgetName: viewModel.budgetName(for: pending),
                            fixedExpenseName: viewModel.fixedExpenseName(for: pending),
                            categoryName: viewModel.categoryName(for: pending),
                            onConfirm: { await viewModel.confirmPending(pending) },
                            onEdit: { editingPending = pending },
                            onDismiss: { await viewModel.dismissPending(pending) }
                        )
                    }
                }
            }

            Section("Recurring") {
                ForEach(viewModel.scheduledTransactions) { scheduled in
                    ScheduledRow(scheduled: scheduled, currencyCode: appState.defaultCurrency)
                        // Swipe: delete + edit, mirroring the other list screens.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDelete = scheduled
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingScheduled = scheduled
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color.appPrimary)
                        }
                        // Leading swipe / long-press: pause or resume.
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task { await viewModel.toggleActive(scheduled) }
                            } label: {
                                Label(
                                    scheduled.isActive ? "Pause" : "Resume",
                                    systemImage: scheduled.isActive ? "pause" : "play"
                                )
                            }
                            .tint(scheduled.isActive ? Color.appWarning : Color.appSuccess)
                        }
                        .contextMenu {
                            Button {
                                editingScheduled = scheduled
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                Task { await viewModel.toggleActive(scheduled) }
                            } label: {
                                Label(
                                    scheduled.isActive ? "Pause" : "Resume",
                                    systemImage: scheduled.isActive ? "pause" : "play"
                                )
                            }
                            Button(role: .destructive) {
                                pendingDelete = scheduled
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle("Scheduled")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingForm = true
                } label: {
                    Label("Add scheduled", systemImage: "plus")
                }
            }
        }
        .overlay {
            if viewModel.scheduledTransactions.isEmpty && viewModel.pendingTransactions.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No Scheduled Transactions",
                    message: "Set up recurring transactions to automate your workflow.",
                    systemImage: "clock.arrow.2.circlepath"
                )
            }
        }
        .sheet(item: $editingPending) { txn in
            NavigationStack {
                TransactionFormView(
                    editing: txn,
                    currency: appState.defaultCurrency,
                    decimalPlaces: appState.decimalPlaces
                ) {
                    await viewModel.load()
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            NavigationStack {
                ScheduledFormView(
                    defaultAccountId: appState.defaultAccountId,
                    decimalPlaces: appState.decimalPlaces
                ) {
                    await viewModel.load()
                }
            }
        }
        .sheet(item: $editingScheduled) { enriched in
            NavigationStack {
                ScheduledFormView(
                    editing: enriched.base,
                    decimalPlaces: appState.decimalPlaces
                ) {
                    await viewModel.load()
                }
            }
        }
        .alert(
            Text(verbatim: "Delete \"\(pendingDelete?.description ?? pendingDelete?.type.rawValue.capitalized ?? "scheduled transaction")\"?"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { scheduled in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteScheduled(scheduled) }
            }
        } message: { _ in
            Text("Already-generated transactions are kept; only the schedule is removed.")
        }
        .task {
            viewModel.currencyCode = appState.defaultCurrency
            _ = await NotificationService.shared.requestPermission()
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
        .onDisappear {
            Task { await viewModel.unsubscribe() }
        }
        .refreshable { await viewModel.load() }
    }
}

/// A recurring scheduled-transaction row, aligned to web's `ScheduledCard`
/// (`web/src/components/scheduled/scheduled-card.tsx`): account avatar with a
/// type badge, title derived by the same budget → fixed-expense → category →
/// description → type precedence as the transaction row, an optional description
/// subtitle, a chip row (category / fixed-expense / tags), a calendar-clock
/// next-due footer, and a type-tinted amount. Row is dimmed while paused.
private struct ScheduledRow: View {
    let scheduled: EnrichedScheduledTransaction
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            AccountAvatar(
                imageUrl: scheduled.accountImageUrl,
                accountType: scheduled.accountType ?? .other,
                size: 40
            )
            .overlay(alignment: .bottomTrailing) { typeBadge }

            VStack(alignment: .leading, spacing: 2) {
                Text(titleDerived.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(1)

                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(Color.appMutedForeground)
                        .lineLimit(1)
                }

                chips

                Label {
                    Text("\(scheduled.isActive ? "Next" : "Paused · next") \(Self.dateFormatter.string(from: scheduled.nextDueDate))")
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                }
                .font(.caption)
                .foregroundStyle(Color.appMutedForeground)
                .padding(.top, 1)
            }

            Spacer(minLength: 8)

            Text(scheduled.amount.asCurrency(code: currencyCode))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 4)
        .opacity(scheduled.isActive ? 1 : 0.6)
    }

    // MARK: - Title derivation (mirrors TransactionRow.derived / web deriveTitle)

    private struct TitleDerived {
        let title: String
        let usedCategory: Bool
        let usedFixed: Bool
        let titleIsDescription: Bool
    }

    private var titleDerived: TitleDerived {
        if let budget = scheduled.budgetName {
            return TitleDerived(title: budget, usedCategory: false, usedFixed: false, titleIsDescription: false)
        }
        if let fixed = scheduled.fixedExpenseName {
            return TitleDerived(title: fixed, usedCategory: false, usedFixed: true, titleIsDescription: false)
        }
        if let cat = scheduled.categoryName {
            return TitleDerived(title: cat, usedCategory: true, usedFixed: false, titleIsDescription: false)
        }
        if let desc = scheduled.description, !desc.isEmpty {
            return TitleDerived(title: desc, usedCategory: false, usedFixed: false, titleIsDescription: true)
        }
        return TitleDerived(title: scheduled.type.rawValue.capitalized, usedCategory: false, usedFixed: false, titleIsDescription: false)
    }

    private var subtitle: String? {
        guard let desc = scheduled.description, !desc.isEmpty, !titleDerived.titleIsDescription else { return nil }
        return desc
    }

    // MARK: - Chips

    @ViewBuilder
    private var chips: some View {
        let chipFixed: String? = titleDerived.usedFixed ? nil : scheduled.fixedExpenseName
        let chipCategoryName: String? = titleDerived.usedCategory ? nil : scheduled.categoryName
        let chipCategoryColor: String? = titleDerived.usedCategory ? nil : scheduled.categoryColor

        if chipFixed != nil || chipCategoryName != nil || !scheduled.tagNames.isEmpty {
            FlowLayout(spacing: 6) {
                if let chipFixed {
                    chip(chipFixed, systemImage: "receipt",
                         fill: Color.appPrimary.opacity(0.12),
                         foreground: Color.appPrimary,
                         border: Color.appBorder)
                }
                if let name = chipCategoryName {
                    categoryChip(name: name, colorHex: chipCategoryColor)
                }
                ForEach(scheduled.tagNames, id: \.self) { tagName in
                    chip(tagName, systemImage: "tag",
                         fill: Color.appCard,
                         foreground: Color.appMutedForeground,
                         border: Color.appBorder)
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func categoryChip(name: String, colorHex: String?) -> some View {
        if let hex = colorHex, let color = Color(hex: hex) {
            chip(name, fill: color.opacity(0.1), foreground: color, border: .clear)
        } else {
            chip(name, fill: Color.appMuted, foreground: Color.appMutedForeground, border: Color.appBorder)
        }
    }

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

    // MARK: - Type styling

    private var amountColor: Color {
        switch scheduled.type {
        case .income: return .appSuccess
        case .expense: return .appDanger
        case .transfer: return .appForeground
        }
    }

    private var typeIcon: String {
        switch scheduled.type {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
}
