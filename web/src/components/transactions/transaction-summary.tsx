import { useMemo } from "react";
import { formatCurrency } from "@/lib/utils/currency";
import type { TransactionWithRelations } from "@/lib/hooks/use-transactions";
import { cn } from "@/lib/utils/cn";

interface Props {
  transactions: TransactionWithRelations[];
}

/**
 * Compact income / expense / net summary for the CURRENTLY FILTERED transaction
 * set (the list is fetched fully client-side, so we derive from the loaded
 * rows). Transfers are excluded — they move money between the user's own
 * accounts, so they're neither income nor expense. Amounts are in minor units.
 * Three columns that hold at the 320px floor.
 */
export function TransactionSummary({ transactions }: Props) {
  const { income, expense } = useMemo(() => {
    let income = 0;
    let expense = 0;
    for (const t of transactions) {
      if (t.type === "income") income += t.amount;
      else if (t.type === "expense") expense += t.amount;
    }
    return { income, expense };
  }, [transactions]);
  const net = income - expense;

  return (
    <div className="grid grid-cols-3 gap-2 rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-card)] p-3">
      <Stat
        label="Income"
        value={formatCurrency(income)}
        className="text-[var(--color-success)]"
      />
      <Stat
        label="Expense"
        value={formatCurrency(expense)}
        className="text-[var(--color-danger)]"
      />
      <Stat
        label="Net"
        value={formatCurrency(net)}
        className={
          net < 0
            ? "text-[var(--color-danger)]"
            : "text-[var(--color-foreground)]"
        }
      />
    </div>
  );
}

function Stat({
  label,
  value,
  className,
}: {
  label: string;
  value: string;
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
    </div>
  );
}
