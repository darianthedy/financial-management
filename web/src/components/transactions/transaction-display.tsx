import { ArrowDownLeft, ArrowUpRight, ArrowLeftRight } from "lucide-react";
import { cn } from "@/lib/utils/cn";
import type { Category, TransactionType } from "@/lib/types/database";

/*
 * Shared presentation helpers for a transaction "row" so the transactions list
 * and the dashboard's recent-transactions card stay visually identical.
 *
 * Emphasis design ("variant E"): the leading avatar carries the account, the
 * title carries the budget (falling back through category → description → type),
 * and category chips sit underneath. See mockups page for the exploration.
 */

/** Minimal shape needed to render the account/budget emphasis. */
export type TxnDisplay = {
  type: TransactionType;
  description: string | null;
  accounts: { name: string } | null;
  transfer_accounts: { name: string } | null;
  categories: Category[];
  budget: { name: string } | null;
};

export function directionIcon(type: TransactionType) {
  return type === "transfer"
    ? ArrowLeftRight
    : type === "income"
      ? ArrowDownLeft
      : ArrowUpRight;
}

export function amountColor(type: TransactionType) {
  return type === "transfer"
    ? "text-[var(--color-foreground)]"
    : type === "income"
      ? "text-[var(--color-success)]"
      : "text-[var(--color-danger)]";
}

const TYPE_LABEL: Record<TransactionType, string> = {
  income: "Income",
  expense: "Expense",
  transfer: "Transfer",
};

/**
 * Title precedence: budget name → a linked category's name → description → the
 * type word. Reports which category (if any) became the title so the chip row
 * can drop it, and whether the description was consumed (so it isn't repeated
 * as a subtitle).
 */
export function deriveTitle(txn: TxnDisplay): {
  title: string;
  usedCategoryId: string | null;
  titleIsDescription: boolean;
} {
  if (txn.budget && txn.type !== "transfer") {
    return { title: txn.budget.name, usedCategoryId: null, titleIsDescription: false };
  }
  if (txn.categories.length) {
    return {
      title: txn.categories[0].name,
      usedCategoryId: txn.categories[0].id,
      titleIsDescription: false,
    };
  }
  if (txn.description) {
    return { title: txn.description, usedCategoryId: null, titleIsDescription: true };
  }
  return { title: TYPE_LABEL[txn.type], usedCategoryId: null, titleIsDescription: false };
}

// Deterministic avatar background so an account keeps the same color everywhere
// (we have no per-account color/image yet — initials stand in for now).
const AVATAR_COLORS = [
  "#2563eb", "#db2777", "#0891b2", "#16a34a",
  "#d97706", "#7c3aed", "#dc2626", "#0d9488",
];

function colorForAccount(name: string): string {
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  return AVATAR_COLORS[hash % AVATAR_COLORS.length];
}

function initials(name: string): string {
  const parts = name.split(" ").filter(Boolean).slice(0, 2);
  return parts.map((w) => w[0]).join("").toUpperCase() || "?";
}

/** Account avatar: colored initials with a small transaction-direction badge. */
export function AccountAvatar({
  name,
  type,
  size = "md",
}: {
  name: string;
  type: TransactionType;
  size?: "sm" | "md";
}) {
  const Icon = directionIcon(type);
  const dims = size === "sm" ? "h-9 w-9 text-[10px]" : "h-10 w-10 text-xs";
  return (
    <div
      className={cn(
        "relative flex shrink-0 items-center justify-center rounded-full font-bold text-white",
        dims,
      )}
      style={{ backgroundColor: colorForAccount(name) }}
    >
      {initials(name)}
      <span className="absolute -bottom-0.5 -right-0.5 flex h-4 w-4 items-center justify-center rounded-full bg-[var(--color-card)] ring-1 ring-[var(--color-border)]">
        <Icon className={cn("h-2.5 w-2.5", amountColor(type))} />
      </span>
    </div>
  );
}

/**
 * The chip row beneath the title: the transfer destination (source is the
 * avatar) plus category chips, minus whichever category became the title.
 * Renders nothing when there is nothing to show. Chips have no icons yet.
 */
export function TransactionChips({
  txn,
  excludeCategoryId,
}: {
  txn: TxnDisplay;
  excludeCategoryId: string | null;
}) {
  const dest = txn.type === "transfer" ? txn.transfer_accounts?.name : undefined;
  const chips = txn.categories.filter((c) => c.id !== excludeCategoryId);
  if (!dest && chips.length === 0) return null;

  return (
    <div className="flex flex-wrap items-center gap-1.5 pt-0.5">
      {dest && (
        <span className="inline-flex items-center rounded-full border border-[var(--color-border)] bg-[var(--color-card)] px-2 py-0.5 text-xs font-medium">
          → {dest}
        </span>
      )}
      {chips.map((c) => (
        <span
          key={c.id}
          className={cn(
            "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
            !c.color &&
              "border border-[var(--color-border)] bg-[var(--color-muted)] text-[var(--color-muted-foreground)]",
          )}
          style={c.color ? { backgroundColor: `${c.color}1a`, color: c.color } : undefined}
        >
          {c.name}
        </span>
      ))}
    </div>
  );
}
