import Foundation
import Supabase

/// Reads and mutates the recurring templates, and reads / confirms / dismisses
/// the server-generated pending transactions. There is no `pending_transactions`
/// table — pending = rows in `transactions` with `status = 'pending'`, generated
/// server-side by the cron + Edge Function (System Design §4.5). The app
/// displays them and lets the user act, while the schedules themselves are fully
/// managed here (create / edit / pause / delete), mirroring web. See §8.7.
actor ScheduledTransactionRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    /// All scheduled transactions: active first, then soonest due — mirroring
    /// web's `useScheduledTransactions` order so paused schedules stay visible
    /// (and editable) rather than vanishing from the list.
    func getAll() async throws -> [ScheduledTransaction] {
        try await client
            .from("scheduled_transactions")
            .select()
            .order("is_active", ascending: false)
            .order("next_due_date")
            .execute()
            .value
    }

    /// Pending transactions awaiting confirmation (`status = 'pending'`).
    func getPendingTransactions() async throws -> [Transaction] {
        try await client
            .from("transactions")
            .select()
            .eq("status", value: TransactionStatus.pending.rawValue)
            .order("date", ascending: false)
            .execute()
            .value
    }

    /// Promote a pending transaction to confirmed; the balance trigger then
    /// applies it to the account (System Design §4.5).
    func confirmPending(id: UUID) async throws {
        try await client
            .from("transactions")
            .update(["status": AnyJSON.string(TransactionStatus.confirmed.rawValue)])
            .eq("id", value: id)
            .execute()
    }

    /// Dismiss a pending transaction; it never affects the balance.
    func dismissPending(id: UUID) async throws {
        try await client
            .from("transactions")
            .update(["status": AnyJSON.string(TransactionStatus.dismissed.rawValue)])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Schedule CRUD

    /// The mutable columns of a schedule, mirroring web's create/update payloads.
    /// `budget_name` / `fixed_expense_name` are lineage names resolved per due
    /// month at generation; the generator copies `category_id` and the tag set.
    struct Fields: Sendable {
        var accountId: UUID
        var type: TransactionType
        var amount: Int64
        var description: String?
        var nextDueDate: Date
        var isActive: Bool
        var categoryId: UUID?
        var budgetName: String?
        var fixedExpenseName: String?
    }

    private struct Insert: Encodable {
        let user_id: UUID
        let account_id: UUID
        let type: String
        let amount: Int64
        let description: String?
        let recurrence: String
        let next_due_date: String
        let is_active: Bool
        let category_id: UUID?
        let budget_name: String?
        let fixed_expense_name: String?
    }

    /// Insert a schedule and return its id, then the caller writes the tag rows.
    func create(_ fields: Fields, tagIds: Set<UUID>) async throws {
        let userId = try await client.auth.session.user.id
        struct Created: Decodable { let id: UUID }

        let created: Created = try await client
            .from("scheduled_transactions")
            .insert(Insert(
                user_id: userId,
                account_id: fields.accountId,
                type: fields.type.rawValue,
                amount: fields.amount,
                description: fields.description,
                recurrence: RecurrenceType.monthly.rawValue,
                next_due_date: DateUtils.yearMonthDay(from: fields.nextDueDate),
                is_active: fields.isActive,
                category_id: fields.categoryId,
                budget_name: fields.budgetName,
                fixed_expense_name: fields.fixedExpenseName
            ))
            .select("id")
            .single()
            .execute()
            .value

        try await setTags(scheduledId: created.id, tagIds: tagIds)
    }

    /// Replace a schedule's editable fields and its tag set.
    func update(id: UUID, fields: Fields, tagIds: Set<UUID>) async throws {
        let payload: [String: AnyJSON] = [
            "account_id": .string(fields.accountId.uuidString),
            "type": .string(fields.type.rawValue),
            "amount": .double(Double(fields.amount)),
            "description": fields.description.map { .string($0) } ?? .null,
            "next_due_date": .string(DateUtils.yearMonthDay(from: fields.nextDueDate)),
            "is_active": .bool(fields.isActive),
            "category_id": fields.categoryId.map { .string($0.uuidString) } ?? .null,
            "budget_name": fields.budgetName.map { .string($0) } ?? .null,
            "fixed_expense_name": fields.fixedExpenseName.map { .string($0) } ?? .null
        ]

        try await client
            .from("scheduled_transactions")
            .update(payload)
            .eq("id", value: id)
            .execute()

        try await setTags(scheduledId: id, tagIds: tagIds)
    }

    /// Pause / resume without editing the rest of the schedule.
    func setActive(id: UUID, isActive: Bool) async throws {
        try await client
            .from("scheduled_transactions")
            .update(["is_active": isActive])
            .eq("id", value: id)
            .execute()
    }

    /// Delete the schedule. Already-generated transactions are kept
    /// (`transactions.scheduled_txn_id` is `ON DELETE SET NULL`); only the
    /// schedule and its tag links (cascade) go away.
    func delete(id: UUID) async throws {
        try await client
            .from("scheduled_transactions")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Enrichment

    /// Resolves account, category, and tag metadata for a list of scheduled
    /// transactions in batched lookups — no N+1. Mirrors the three-way
    /// `Promise.all` in the web hook (use-scheduled-transactions.ts lines 51-78).
    func enrich(_ scheduled: [ScheduledTransaction]) async throws -> [EnrichedScheduledTransaction] {
        guard !scheduled.isEmpty else { return [] }

        struct AccountRow: Decodable {
            let id: UUID; let name: String; let type: AccountType; let imageUrl: String?
            enum CodingKeys: String, CodingKey {
                case id, name, type; case imageUrl = "image_url"
            }
        }
        struct CategoryRow: Decodable { let id: UUID; let name: String; let color: String? }
        struct TagLinkRow: Decodable {
            let scheduledTransactionId: UUID; let tagId: UUID
            enum CodingKeys: String, CodingKey {
                case scheduledTransactionId = "scheduled_transaction_id"
                case tagId = "tag_id"
            }
        }
        struct TagRow: Decodable { let id: UUID; let name: String }

        let accountIds = Array(Set(scheduled.map(\.accountId)))
        let catIds     = Array(Set(scheduled.compactMap(\.categoryId)))
        let schedIds   = scheduled.map(\.id)

        // Accounts and tag links in parallel; categories conditional on catIds.
        async let accountsFetch: [AccountRow] = client
            .from("accounts")
            .select("id, name, type, image_url")
            .in("id", value: accountIds)
            .execute().value

        async let tagLinksFetch: [TagLinkRow] = client
            .from("scheduled_transaction_tags")
            .select("scheduled_transaction_id, tag_id")
            .in("scheduled_transaction_id", value: schedIds)
            .execute().value

        let accounts = try await accountsFetch
        let tagLinks = try await tagLinksFetch

        let categories: [CategoryRow]
        if catIds.isEmpty {
            categories = []
        } else {
            categories = try await client
                .from("categories")
                .select("id, name, color")
                .in("id", value: catIds)
                .execute().value
        }

        let tagIds = Array(Set(tagLinks.map(\.tagId)))
        let tagRows: [TagRow]
        if tagIds.isEmpty {
            tagRows = []
        } else {
            tagRows = try await client
                .from("tags")
                .select("id, name")
                .in("id", value: tagIds)
                .execute().value
        }

        let accountById  = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let tagNameById  = Dictionary(uniqueKeysWithValues: tagRows.map { ($0.id, $0.name) })

        var tagsByScheduled: [UUID: [String]] = [:]
        for link in tagLinks {
            if let name = tagNameById[link.tagId] {
                tagsByScheduled[link.scheduledTransactionId, default: []].append(name)
            }
        }

        return scheduled.map { s in
            let acct = accountById[s.accountId]
            let cat  = s.categoryId.flatMap { categoryById[$0] }
            return EnrichedScheduledTransaction(
                base: s,
                accountName: acct?.name,
                accountImageUrl: acct?.imageUrl,
                accountType: acct?.type,
                categoryName: cat?.name,
                categoryColor: cat?.color,
                tagNames: tagsByScheduled[s.id] ?? []
            )
        }
    }

    // MARK: - Tags (many-to-many via scheduled_transaction_tags)

    func getTagIds(scheduledId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable { let tag_id: UUID }

        let rows: [Row] = try await client
            .from("scheduled_transaction_tags")
            .select("tag_id")
            .eq("scheduled_transaction_id", value: scheduledId)
            .execute()
            .value

        return Set(rows.map(\.tag_id))
    }

    func setTags(scheduledId: UUID, tagIds: Set<UUID>) async throws {
        try await client
            .from("scheduled_transaction_tags")
            .delete()
            .eq("scheduled_transaction_id", value: scheduledId)
            .execute()

        guard !tagIds.isEmpty else { return }

        struct Row: Encodable {
            let scheduled_transaction_id: UUID
            let tag_id: UUID
        }

        let rows = tagIds.map { Row(scheduled_transaction_id: scheduledId, tag_id: $0) }
        try await client
            .from("scheduled_transaction_tags")
            .insert(rows)
            .execute()
    }
}
