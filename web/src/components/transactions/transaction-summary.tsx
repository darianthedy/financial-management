import { useMemo } from "react";
import { formatCurrency } from "@/lib/utils/currency";
import type { TransactionSummaryRow } from "@/lib/hooks/use-transactions";
import { cn } from "@/lib/utils/cn";

interface Props {
  transactions: TransactionSummaryRow[];
}

/**
 * Income / expense / net summary plus a texture row, for the CURRENTLY FILTERED
 * transaction set across every page (the Transactions page fetches the whole
 * filtered set on demand and passes it here). Computed on demand — the page only
 * mounts this when the user opens the summary.
 *
 * Money math uses CONFIRMED rows only: pending rows haven't happened yet and are
 * surfaced separately as a projection, while dismissed (cancelled) rows are
 * excluded entirely. Transfers move money between the user's own accounts, so
 * they're neither income nor expense — they get their own "Transfer" stat rather
 * than touching net. Amounts are in minor units. Rendered inside the Summary
 * dialog, so it's a bare three-column grid (the dialog supplies the card
 * chrome); three columns hold at the 320px floor.
 */
export function TransactionSummary({ transactions }: Props) {
  const {
    confirmedIncome,
    pendingIncome,
    confirmedExpense,
    pendingExpense,
    transferTotal,
    largestExpense,
    count,
  } = useMemo(() => {
    let confirmedIncome = 0;
    let pendingIncome = 0;
    let confirmedExpense = 0;
    let pendingExpense = 0;
    let transferTotal = 0;
    let largestExpense = 0;
    for (const t of transactions) {
      if (t.status === "dismissed") continue; // cancelled — never counts
      if (t.type === "income") {
        if (t.status === "pending") pendingIncome += t.amount;
        else confirmedIncome += t.amount;
      } else if (t.type === "expense") {
        if (t.status === "pending") pendingExpense += t.amount;
        else {
          confirmedExpense += t.amount;
          if (t.amount > largestExpense) largestExpense = t.amount;
        }
      } else if (t.type === "transfer" && t.status !== "pending") {
        transferTotal += t.amount;
      }
    }
    return {
      confirmedIncome,
      pendingIncome,
      confirmedExpense,
      pendingExpense,
      transferTotal,
      largestExpense,
      count: transactions.length,
    };
  }, [transactions]);

  const net = confirmedIncome - confirmedExpense;
  const projectedNet = net + pendingIncome - pendingExpense;
  const hasPending = pendingIncome > 0 || pendingExpense > 0;

  return (
    <div className="grid grid-cols-3 gap-x-3 gap-y-4">
      <Stat
        label="Income"
        value={formatCurrency(confirmedIncome)}
        sub={pendingIncome > 0 ? `+${formatCurrency(pendingIncome)} pending` : undefined}
        className="text-[var(--color-success)]"
      />
      <Stat
        label="Expense"
        value={formatCurrency(confirmedExpense)}
        sub={pendingExpense > 0 ? `+${formatCurrency(pendingExpense)} pending` : undefined}
        className="text-[var(--color-danger)]"
      />
      <Stat
        label="Net"
        value={formatCurrency(net)}
        sub={hasPending ? `≈ ${formatCurrency(projectedNet)} projected` : undefined}
        className={
          net < 0
            ? "text-[var(--color-danger)]"
            : "text-[var(--color-foreground)]"
        }
      />
      <Stat label="Count" value={`${count} txns`} />
      <Stat label="Largest expense" value={formatCurrency(largestExpense)} />
      <Stat label="Transfers" value={formatCurrency(transferTotal)} />
    </div>
  );
}

function Stat({
  label,
  value,
  sub,
  className,
}: {
  label: string;
  value: string;
  sub?: string;
  className?: string;
}) {
  return (
    <div className="flex min-w-0 flex-col gap-0.5">
      <span className="text-xs text-[var(--color-muted-foreground)]">
        {label}
      </span>
      <span className={cn("truncate text-sm font-semibold", className)}>
        {value}
      </span>
      {sub && (
        <span className="truncate text-xs text-[var(--color-muted-foreground)]">
          {sub}
        </span>
      )}
    </div>
  );
}
