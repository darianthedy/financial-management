import { useNavigate } from "react-router-dom";
import { Plus } from "lucide-react";
import type { TransactionWithRelations } from "@/lib/hooks/use-transactions";
import { widestCurrencyNumber } from "@/lib/utils/currency";
import { formatDate } from "@/lib/utils/date";
import { cn } from "@/lib/utils/cn";
import { AmountColumn } from "@/components/shared/amount-column";
import { TransactionRow } from "./transaction-row";
import { Button } from "@/components/ui/button";
import { CenteredSpinner, EmptyState } from "@/components/ui/misc";

/** One date's worth of rows plus its net (income − expense; transfers excluded). */
interface DateGroup {
  date: string;
  txns: TransactionWithRelations[];
  net: number;
}

/**
 * Partition the (already date-descending) page into per-date groups, preserving
 * order. Each group's net sums income as positive and expense as negative;
 * transfers move money between the user's own accounts, so they're net-zero and
 * excluded.
 */
function groupByDate(txns: TransactionWithRelations[]): DateGroup[] {
  const groups: DateGroup[] = [];
  let current: DateGroup | null = null;
  for (const txn of txns) {
    if (!current || current.date !== txn.date) {
      current = { date: txn.date, txns: [], net: 0 };
      groups.push(current);
    }
    current.txns.push(txn);
    if (txn.type === "income") current.net += txn.amount;
    else if (txn.type === "expense") current.net -= txn.amount;
  }
  return groups;
}

/**
 * Sticky per-date heading: the absolute date on the left, the item count and the
 * day's net on the right. The net renders through the same `AmountColumn` as the
 * rows (sharing `widestAmount`) so its currency symbol and digits line up exactly
 * with the amount column below. It's tinted green/red (muted when it nets to
 * zero, e.g. a transfer-only day) and carries an explicit +/− sign.
 */
function DateGroupHeader({
  group,
  widestAmount,
}: {
  group: DateGroup;
  widestAmount: string;
}) {
  const count = group.txns.length;
  const netColor =
    group.net > 0
      ? "text-[var(--color-success)]"
      : group.net < 0
        ? "text-[var(--color-danger)]"
        : "text-[var(--color-muted-foreground)]";
  return (
    // Pin flush to the top of the scroll area. The scrolling ancestor (<main>)
    // has p-4/md:p-6 padding, and sticky `top-0` would pin below that padding —
    // leaving a band where the previous row shows through. A negative top equal to
    // that padding cancels it so the header sits at the very top; the opaque
    // background + bottom border then read as a solid bar rather than a float.
    <div className="sticky -top-4 z-10 flex items-baseline gap-3 border-b border-[var(--color-border)] bg-[var(--color-background)] px-3 pb-1.5 pt-2.5 md:-top-6">
      <span className="text-xs font-bold uppercase tracking-wide text-[var(--color-muted-foreground)]">
        {formatDate(group.date)}
      </span>
      <span className="ml-auto text-xs text-[var(--color-muted-foreground)]">
        {count} {count === 1 ? "item" : "items"}
      </span>
      {/* Same component + shared width as the rows, so symbol and digits align
          into one column. `signed` forces a leading "+" on a positive net; a
          negative net already carries Intl's "−", and a zero net shows neither. */}
      <AmountColumn
        minorUnits={group.net}
        widestNumber={widestAmount}
        signed={group.net > 0}
        className={cn("text-sm font-semibold", netColor)}
      />
      {/* Reserves the width of a row's trailing ⋮ actions button (p-1 + a 1rem
          icon = 1.5rem) plus its gap, so the net's right edge lines up with the
          amount column below instead of running to the container edge. */}
      <span aria-hidden className="w-6 shrink-0" />
    </div>
  );
}

interface Props {
  /** Rows for the current page (already filtered and windowed by the hook). */
  transactions: TransactionWithRelations[];
  loading: boolean;
  /** When true the "Add transaction" button links to /transactions/new. */
  showAddButton?: boolean;
  /** Hide the list's own "Transactions" heading (e.g. when the page already has one). */
  hideHeader?: boolean;
  /** Called after a row is confirmed/dismissed/edited/deleted so the owner can refetch. */
  onMutated?: () => void;
}

export function TransactionList({
  transactions,
  loading,
  showAddButton = true,
  hideHeader = false,
  onMutated,
}: Props) {
  const navigate = useNavigate();

  const groups = groupByDate(transactions);

  // Size the amount column to the widest value so every row's currency symbol
  // and digits align into a single tidy column — across all groups, not just
  // within one day, so the whole list shares one column. The per-day net totals
  // are part of the same column, so they're folded in too (a sum can be wider
  // than any single row).
  const widestAmount = widestCurrencyNumber([
    ...transactions.map((t) => t.amount),
    ...groups.map((g) => Math.abs(g.net)),
  ]);

  if (loading) return <CenteredSpinner />;

  return (
    <div className="space-y-1">
      {!hideHeader && (
        <div className="flex items-center justify-between pb-1">
          <h2 className="text-base font-semibold text-[var(--color-muted-foreground)]">
            Transactions
          </h2>
          {showAddButton && (
            <Button
              size="sm"
              variant="outline"
              onClick={() => navigate("/transactions/new")}
            >
              <Plus className="h-4 w-4" /> Add
            </Button>
          )}
        </div>
      )}
      {transactions.length === 0 ? (
        <EmptyState
          title="No transactions"
          description="Add your first transaction to get started."
          action={
            showAddButton ? (
              <Button onClick={() => navigate("/transactions/new")}>
                Add transaction
              </Button>
            ) : undefined
          }
        />
      ) : (
        <div>
          {groups.map((group) => (
            <div key={group.date}>
              <DateGroupHeader group={group} widestAmount={widestAmount} />
              <div className="divide-y divide-[var(--color-border)]">
                {group.txns.map((txn) => (
                  <TransactionRow
                    key={txn.id}
                    txn={txn}
                    widestAmount={widestAmount}
                    showDate={false}
                    onMutated={onMutated}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
