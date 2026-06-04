// Hand-written Supabase types shim.
// Replace with: supabase gen types typescript --project-id <id> > src/lib/types/database.ts

export type AccountType =
  | "bank_account"
  | "credit_card"
  | "digital_wallet"
  | "cash"
  | "other";

export type TransactionType = "income" | "expense" | "transfer";
export type TransactionStatus = "confirmed" | "pending" | "dismissed";
export type RecurrenceType = "monthly";

// ---- Row types (no circular references) ----

type AccountRow = {
  id: string;
  user_id: string;
  name: string;
  type: AccountType;
  currency: string;
  starting_balance: number;
  is_archived: boolean;
  created_at: string;
  updated_at: string;
};

type TransactionRow = {
  id: string;
  user_id: string;
  account_id: string;
  transfer_account_id: string | null;
  type: TransactionType;
  status: TransactionStatus;
  amount: number;
  currency: string;
  description: string | null;
  date: string;
  budget_id: string | null;
  scheduled_txn_id: string | null;
  fixed_expense_id: string | null;
  created_at: string;
  updated_at: string;
};

type CategoryRow = {
  id: string;
  user_id: string;
  name: string;
  icon: string | null;
  color: string | null;
  created_at: string;
};

type TagRow = {
  id: string;
  user_id: string;
  name: string;
  created_at: string;
};

type TransactionCategoryRow = { transaction_id: string; category_id: string };
type TransactionTagRow = { transaction_id: string; tag_id: string };

type CurrencyRow = {
  code: string;
  name: string;
  symbol: string;
  decimal_places: number;
  created_at: string;
};

type UserSettingsRow = {
  user_id: string;
  default_currency: string;
  created_at: string;
  updated_at: string;
};

type AccountMonthlyBalanceRow = {
  account_id: string;
  year_month: string;
  balance: number;
  updated_at: string;
};

// Flat, self-contained budget entry. Identity = (name + currency). One row per month.
// Carry-over is derived live in v_budget_progress; there is no stored carry-over column.
type BudgetRow = {
  id: string;
  user_id: string;
  name: string;
  year_month: string;
  currency: string;
  periodic_amount: number;
  created_at: string;
  updated_at: string;
};

// ---- Database interface (supabase-js 2.x GenericSchema shape) ----

export interface Database {
  public: {
    Tables: {
      accounts: {
        Row: AccountRow;
        Insert: {
          id?: string;
          user_id: string;
          name: string;
          type?: AccountType;
          currency?: string;
          starting_balance?: number;
          is_archived?: boolean;
        };
        Update: {
          id?: string;
          user_id?: string;
          name?: string;
          type?: AccountType;
          currency?: string;
          starting_balance?: number;
          is_archived?: boolean;
        };
        Relationships: [];
      };
      account_monthly_balances: {
        Row: AccountMonthlyBalanceRow;
        Insert: { account_id: string; year_month: string; balance?: number };
        Update: { account_id?: string; year_month?: string; balance?: number };
        Relationships: [];
      };
      budgets: {
        Row: BudgetRow;
        Insert: {
          id?: string;
          user_id: string;
          name: string;
          year_month: string;
          currency?: string;
          periodic_amount: number;
        };
        Update: {
          name?: string;
          year_month?: string;
          currency?: string;
          periodic_amount?: number;
        };
        Relationships: [];
      };
      transactions: {
        Row: TransactionRow;
        Insert: {
          id?: string;
          user_id: string;
          account_id: string;
          transfer_account_id?: string | null;
          type: TransactionType;
          status?: TransactionStatus;
          amount: number;
          currency?: string;
          description?: string | null;
          date?: string;
          budget_id?: string | null;
          scheduled_txn_id?: string | null;
          fixed_expense_id?: string | null;
        };
        Update: {
          account_id?: string;
          transfer_account_id?: string | null;
          type?: TransactionType;
          status?: TransactionStatus;
          amount?: number;
          currency?: string;
          description?: string | null;
          date?: string;
          budget_id?: string | null;
          fixed_expense_id?: string | null;
        };
        Relationships: [];
      };
      categories: {
        Row: CategoryRow;
        Insert: { id?: string; user_id: string; name: string; icon?: string | null; color?: string | null };
        Update: { name?: string; icon?: string | null; color?: string | null };
        Relationships: [];
      };
      tags: {
        Row: TagRow;
        Insert: { id?: string; user_id: string; name: string };
        Update: { name?: string };
        Relationships: [];
      };
      transaction_categories: {
        Row: TransactionCategoryRow;
        Insert: TransactionCategoryRow;
        Update: Partial<TransactionCategoryRow>;
        Relationships: [];
      };
      transaction_tags: {
        Row: TransactionTagRow;
        Insert: TransactionTagRow;
        Update: Partial<TransactionTagRow>;
        Relationships: [];
      };
      currencies: {
        Row: CurrencyRow;
        Insert: { code: string; name: string; symbol?: string; decimal_places?: number };
        Update: { name?: string; symbol?: string; decimal_places?: number };
        Relationships: [];
      };
      user_settings: {
        Row: UserSettingsRow;
        Insert: { user_id: string; default_currency?: string };
        Update: { default_currency?: string };
        Relationships: [];
      };
    };
    Views: {
      v_account_current_balance: {
        Row: { account_id: string; year_month: string; current_balance: number };
        Relationships: [];
      };
      v_monthly_cashflow: {
        Row: {
          user_id: string;
          year_month: string;
          total_income: number;
          total_expense: number;
          net: number;
        };
        Relationships: [];
      };
      v_budget_progress: {
        Row: {
          budget_id: string;
          user_id: string;
          budget_name: string;
          currency: string;
          year_month: string;
          periodic_amount: number;
          carry_over_amount: number;
          effective_amount: number;
          spent: number;
          remaining: number;
        };
        Relationships: [];
      };
      v_spending_by_category: {
        Row: {
          user_id: string;
          year_month: string;
          category_id: string;
          category_name: string;
          icon: string | null;
          color: string | null;
          total_amount: number;
        };
        Relationships: [];
      };
    };
    Functions: Record<string, never>;
    Enums: {
      account_type: AccountType;
      transaction_type: TransactionType;
      transaction_status: TransactionStatus;
      recurrence_type: RecurrenceType;
    };
    CompositeTypes: Record<string, never>;
  };
}

// Convenience aliases
export type Account = Database["public"]["Tables"]["accounts"]["Row"];
export type Transaction = Database["public"]["Tables"]["transactions"]["Row"];
export type Budget = Database["public"]["Tables"]["budgets"]["Row"];
export type Category = Database["public"]["Tables"]["categories"]["Row"];
export type Tag = Database["public"]["Tables"]["tags"]["Row"];
export type Currency = Database["public"]["Tables"]["currencies"]["Row"];
export type UserSettings = Database["public"]["Tables"]["user_settings"]["Row"];
export type AccountCurrentBalance = Database["public"]["Views"]["v_account_current_balance"]["Row"];
export type MonthlyCashflow = Database["public"]["Views"]["v_monthly_cashflow"]["Row"];
export type SpendingByCategory = Database["public"]["Views"]["v_spending_by_category"]["Row"];
export type BudgetProgress = Database["public"]["Views"]["v_budget_progress"]["Row"];
