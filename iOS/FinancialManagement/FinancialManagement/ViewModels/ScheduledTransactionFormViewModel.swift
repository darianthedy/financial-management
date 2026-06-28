import Foundation
import Observation
import Supabase

/// Drives the create / edit form for a recurring schedule, mirroring web's
/// `ScheduledForm` (web/src/components/scheduled/scheduled-form.tsx): type →
/// account → amount → next due date → repeats (monthly, fixed) → description →
/// budget (by lineage name) → category → fixed expense (expense only, by lineage
/// name) → tags → active. Scheduled transfers are not supported (the generator
/// can't copy a destination), so only income / expense, and the amount must be
/// strictly positive — both matching web's `scheduledTransactionFormSchema`.
@Observable
@MainActor
final class ScheduledTransactionFormViewModel {
    // Switching to income drops the fixed-expense link (fixed expenses are
    // expense-only), matching web. didSet does not fire during init, so the
    // edit-mode prefill is preserved.
    var type: TransactionType = .expense {
        didSet {
            guard type != oldValue else { return }
            if type != .expense { fixedExpenseName = nil }
        }
    }
    var amount: String = ""
    var accountId: UUID?
    var categoryId: UUID?
    var budgetName: String?
    var fixedExpenseName: String?
    var description: String = ""
    var nextDueDate = Date()
    var isActive = true
    var selectedTags: Set<UUID> = []

    var isSaving = false
    var errorMessage: String?
    var didSave = false

    let editing: ScheduledTransaction?
    private let decimalPlaces: Int
    private let repository = ScheduledTransactionRepository()

    /// Snapshot of the editable fields the form opened with, so unsaved edits can
    /// be detected for the discard-changes guard. Tags load asynchronously, so
    /// they're tracked separately.
    private struct Snapshot: Equatable {
        var type: TransactionType
        var amount: String
        var accountId: UUID?
        var categoryId: UUID?
        var budgetName: String?
        var fixedExpenseName: String?
        var description: String
        var nextDueDate: Date
        var isActive: Bool
    }
    private var initialSnapshot: Snapshot!
    private var initialTags: Set<UUID> = []

    private var currentSnapshot: Snapshot {
        Snapshot(
            type: type, amount: amount, accountId: accountId,
            categoryId: categoryId, budgetName: budgetName,
            fixedExpenseName: fixedExpenseName, description: description,
            nextDueDate: nextDueDate, isActive: isActive
        )
    }

    var hasChanges: Bool {
        currentSnapshot != initialSnapshot || selectedTags != initialTags
    }

    init(
        editing schedule: ScheduledTransaction? = nil,
        defaultAccountId: UUID? = nil,
        decimalPlaces: Int = 2
    ) {
        self.decimalPlaces = decimalPlaces
        self.editing = schedule

        if let schedule {
            // Transfers can't be scheduled, but guard the prefill anyway so a
            // legacy row never lands the picker on an unsupported type.
            self.type = schedule.type == .income ? .income : .expense
            self.amount = String(CurrencyUtils.toDisplayAmount(schedule.amount, decimalPlaces: decimalPlaces))
            self.accountId = schedule.accountId
            self.categoryId = schedule.categoryId
            self.budgetName = schedule.budgetName
            self.fixedExpenseName = schedule.fixedExpenseName
            self.description = schedule.description ?? ""
            self.nextDueDate = schedule.nextDueDate
            self.isActive = schedule.isActive
        } else {
            self.accountId = defaultAccountId
        }

        self.initialSnapshot = currentSnapshot
    }

    func loadTags() async {
        guard let schedule = editing else { return }
        do {
            selectedTags = try await repository.getTagIds(scheduledId: schedule.id)
            initialTags = selectedTags
        } catch {}
    }

    /// Raw minor units parsed from the field, or nil when not a number.
    private var parsedMinorUnits: Int64? {
        guard let value = Double(amount) else { return nil }
        return CurrencyUtils.toMinorUnits(value, decimalPlaces: decimalPlaces)
    }

    var isValid: Bool {
        guard let minorUnits = parsedMinorUnits, minorUnits > 0 else { return false }
        guard accountId != nil else { return false }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= 200
    }

    func save() async {
        guard isValid, let minorUnits = parsedMinorUnits, let accountId else { return }

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDescription.count > 200 {
            errorMessage = "Description must be 200 characters or fewer."
            return
        }

        // Reassert: fixed-expense link is expense-only (didSet guards during edits,
        // but an explicit check before save matches web's Zod schema).
        let effectiveFixedExpenseName = type == .expense ? fixedExpenseName : nil

        let fields = ScheduledTransactionRepository.Fields(
            accountId: accountId,
            type: type,
            amount: minorUnits,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            nextDueDate: nextDueDate,
            isActive: isActive,
            categoryId: categoryId,
            budgetName: budgetName,
            fixedExpenseName: effectiveFixedExpenseName
        )

        isSaving = true
        defer { isSaving = false }

        do {
            if let existing = editing {
                try await repository.update(id: existing.id, fields: fields, tagIds: selectedTags)
            } else {
                try await repository.create(fields, tagIds: selectedTags)
            }
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
