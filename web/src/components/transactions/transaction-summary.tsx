import { useMemo } from "react";
import { ChevronRight } from "lucide-react";
import { formatCurrency } from "@/lib/utils/currency";
import type { TransactionSummaryRow } from "@/lib/hooks/use-transactions";
import { cn } from "@/lib/utils/cn";

interface Props {
  transactions: TransactionSummaryRow[];
}

/**
 * Income / expense / net / count / largest-expense (and, where it applies,
 * transfer out / in) for the CURRENTLY FILTERED transaction set across every
 * page (the Transactions page fetches the whole filtered set on demand and
 * passes it here). Shows an overall summary plus collapsible breakdowns by
 * account, category, budget, fixed expense, and tag. Computed on demand — the
 * page only mounts this when the user opens the summary.
 *
 * Money math uses CONFIRMED rows only: pending rows haven't happened yet (the
 * overall block surfaces them separately as a projection), while dismissed
 * (cancelled) rows are excluded entirely. Transfers move money between the
 * user's own accounts, so they're neither income nor expense — they're reported
 * separately as "Transfer out" (leaving the source account) and "Transfer in"
 * (reaching the destination). That split is only meaningful for the whole set
 * and per account, so transfers appear only in the overall summary and the By
 * account breakdown — not under category/budget/fixed/tag. Amounts are in minor
 * units.
 *
 * Each breakdown lists one group per distinct value present (budgets/fixed
 * expenses are identified by name across months); a transaction with several
 * tags contributes to every one of its tags. Groups are sorted by total
 * activity so the biggest movers come first. Rendered inside the Summary dialog,
 * so the stat grid is a bare three-column layout (the dialog supplies the card
 * chrome); three columns hold at the 320px floor.
 */
export function TransactionSummary({ transactions }: Props) {
  const { overall, byAccount, byCategory, byBudget, byFixed, byTag } = useMemo(() => {
    const overall = computeStats(transactions);

    // For each facet, bucket rows by name then reduce each bucket to its stats.
    const groupBy = (key: (r: TransactionSummaryRow) => string | null) => {
      const buckets = new Map<string, TransactionSummaryRow[]>();
      for (const t of transactions) {
        const name = key(t);
        if (name == null) continue; // only rows that have a value for this facet
        const bucket = buckets.get(name);
        if (bucket) bucket.push(t);
        else buckets.set(name, [t]);
      }
      return [...buckets.entries()]
        .map(([name, rows]) => ({ name, stats: computeStats(rows) }))
        .sort((a, b) => activity(b.stats) - activity(a.stats));
    };

    // A transaction can carry several tags, so it lands in every tag's bucket.
    const tagBuckets = new Map<string, TransactionSummaryRow[]>();
    for (const t of transactions) {
      for (const name of t.tagNames) {
        const bucket = tagBuckets.get(name);
        if (bucket) bucket.push(t);
        else tagBuckets.set(name, [t]);
      }
    }
    const byTag = [...tagBuckets.entries()]
      .map(([name, rows]) => ({ name, stats: computeStats(rows) }))
      .sort((a, b) => activity(b.stats) - activity(a.stats));

    return {
      overall,
      byAccount: computeAccountStats(transactions),
      byCategory: groupBy((r) => r.categoryName),
      byBudget: groupBy((r) => r.budgetName),
      byFixed: groupBy((r) => r.fixedExpenseName),
      byTag,
    };
  }, [transactions]);

  return (
    <div className="-mr-2 max-h-[70vh] space-y-5 overflow-y-auto pr-2">
      <StatGrid stats={overall} showPending showTransfers />
      <Breakdown title="By account" groups={byAccount} showTransfers />
      <Breakdown title="By category" groups={byCategory} />
      <Breakdown title="By budget" groups={byBudget} />
      <Breakdown title="By fixed expense" groups={byFixed} expenseOnly />
      <Breakdown title="By tag" groups={byTag} hideTotal />
    </div>
  );
}

interface Stats {
  income: number; // confirmed
  pendingIncome: number;
  expense: number; // confirmed
  pendingExpense: number;
  transferOut: number;
  transferIn: number;
  largestExpense: number;
  count: number;
}

function emptyStats(): Stats {
  return {
    income: 0,
    pendingIncome: 0,
    expense: 0,
    pendingExpense: 0,
    transferOut: 0,
    transferIn: 0,
    largestExpense: 0,
    count: 0,
  };
}

/** Total money moved through a group, used only to order the breakdown lists. */
function activity(s: Stats): number {
  return s.income + s.expense + s.transferOut + s.transferIn;
}

/**
 * Sum a section's groups into a single total, so each total reconciles with the
 * rows above it (column sums). `largestExpense` is the max across groups, not a
 * sum; everything else adds up. Note tags can share transactions and account
 * transfers count on both sides, so a section total may exceed the overall — it
 * reflects exactly what the section lists.
 */
function sumStats(groups: { stats: Stats }[]): Stats {
  const t = emptyStats();
  for (const { stats } of groups) {
    t.income += stats.income;
    t.pendingIncome += stats.pendingIncome;
    t.expense += stats.expense;
    t.pendingExpense += stats.pendingExpense;
    t.transferOut += stats.transferOut;
    t.transferIn += stats.transferIn;
    t.count += stats.count;
    t.largestExpense = Math.max(t.largestExpense, stats.largestExpense);
  }
  return t;
}

/**
 * Reduce a set of rows to its stats. A transfer counts as both an out and an in
 * (it leaves one account and enters another), so for the whole set both totals
 * equal the transfer volume; the per-account split lives in computeAccountStats.
 */
function computeStats(rows: TransactionSummaryRow[]): Stats {
  const s = emptyStats();
  for (const t of rows) {
    if (t.status === "dismissed") continue; // cancelled — never counts
    if (t.type === "income") {
      if (t.status === "pending") s.pendingIncome += t.amount;
      else s.income += t.amount;
    } else if (t.type === "expense") {
      if (t.status === "pending") s.pendingExpense += t.amount;
      else {
        s.expense += t.amount;
        if (t.amount > s.largestExpense) s.largestExpense = t.amount;
      }
    } else if (t.type === "transfer" && t.status !== "pending") {
      s.transferOut += t.amount;
      s.transferIn += t.amount;
    }
  }
  s.count = rows.length;
  return s;
}

/**
 * Group by account. Unlike the other facets, a transfer touches TWO accounts:
 * its amount is an out on the source (`accountName`) and an in on the
 * destination (`transferAccountName`), so it lands in both buckets. Income and
 * expense land in their single account. Each association is counted once per
 * account it touches.
 */
function computeAccountStats(
  rows: TransactionSummaryRow[],
): { name: string; stats: Stats }[] {
  const byName = new Map<string, Stats>();
  const bucket = (name: string) => {
    let s = byName.get(name);
    if (!s) {
      s = emptyStats();
      byName.set(name, s);
    }
    return s;
  };
  for (const t of rows) {
    if (t.status === "dismissed") continue;
    if (t.type === "transfer") {
      if (t.status === "pending") continue; // confirmed money only
      if (t.accountName) {
        const s = bucket(t.accountName);
        s.transferOut += t.amount;
        s.count += 1;
      }
      if (t.transferAccountName) {
        const s = bucket(t.transferAccountName);
        s.transferIn += t.amount;
        s.count += 1;
      }
      continue;
    }
    if (!t.accountName) continue;
    const s = bucket(t.accountName);
    s.count += 1;
    if (t.type === "income") {
      if (t.status === "pending") s.pendingIncome += t.amount;
      else s.income += t.amount;
    } else {
      if (t.status === "pending") s.pendingExpense += t.amount;
      else {
        s.expense += t.amount;
        if (t.amount > s.largestExpense) s.largestExpense = t.amount;
      }
    }
  }
  return [...byName.entries()]
    .map(([name, stats]) => ({ name, stats }))
    .sort((a, b) => activity(b.stats) - activity(a.stats));
}

/**
 * A collapsible facet section. Each group renders the full stat grid, except
 * when `expenseOnly` is set (fixed expenses) — there each group is a compact
 * name/expense row, since that's the only figure that matters for them.
 */
function Breakdown({
  title,
  groups,
  showTransfers,
  expenseOnly,
  hideTotal,
}: {
  title: string;
  groups: { name: string; stats: Stats }[];
  showTransfers?: boolean;
  expenseOnly?: boolean;
  hideTotal?: boolean;
}) {
  if (groups.length === 0) return null;
  const total = sumStats(groups);
  return (
    <details className="group rounded-[var(--radius)] border border-[var(--color-border)]">
      <summary className="flex cursor-pointer list-none items-center gap-2 px-3 py-2 text-sm font-medium">
        <ChevronRight className="h-4 w-4 shrink-0 text-[var(--color-muted-foreground)] transition-transform group-open:rotate-90" />
        <span className="truncate">{title}</span>
        <span className="ml-auto shrink-0 text-xs text-[var(--color-muted-foreground)]">
          {groups.length}
        </span>
      </summary>
      <div
        className={cn(
          "border-t border-[var(--color-border)] px-3 py-3",
          expenseOnly ? "space-y-2" : "space-y-4",
        )}
      >
        {groups.map((g) =>
          expenseOnly ? (
            <div
              key={g.name}
              className="flex items-baseline justify-between gap-3"
            >
              <span className="truncate text-sm font-medium">{g.name}</span>
              <span className="shrink-0 text-sm font-semibold text-[var(--color-danger)]">
                {formatCurrency(g.stats.expense)}
              </span>
            </div>
          ) : (
            <div key={g.name} className="space-y-2">
              <p className="truncate text-sm font-medium">{g.name}</p>
              <StatGrid stats={g.stats} showTransfers={showTransfers} />
            </div>
          ),
        )}
        {hideTotal ? null : expenseOnly ? (
          <div className="flex items-baseline justify-between gap-3 border-t border-[var(--color-border)] pt-2">
            <span className="text-sm font-semibold">Total</span>
            <span className="shrink-0 text-sm font-semibold text-[var(--color-danger)]">
              {formatCurrency(total.expense)}
            </span>
          </div>
        ) : (
          <div className="space-y-2 border-t border-[var(--color-border)] pt-3">
            <p className="text-sm font-semibold">Total</p>
            <StatGrid stats={total} showTransfers={showTransfers} />
          </div>
        )}
      </div>
    </details>
  );
}

/**
 * The stat row. On desktop (lg+) it's a single equal-width row — Net, Income,
 * Expense, [Transfer in, Transfer out], Count, Largest expense; below that it
 * stacks as label/value rows (label left, value right) so the currency stays
 * readable at narrow widths. Net is green when positive, red when negative.
 */
function StatGrid({
  stats,
  showPending,
  showTransfers,
}: {
  stats: Stats;
  showPending?: boolean;
  showTransfers?: boolean;
}) {
  // Net includes transfers: money in (income + transfer in) less money out
  // (expense + transfer out). For the whole set transfer in == transfer out so
  // they cancel; per account the difference is the net flow through it.
  const net =
    stats.income + stats.transferIn - stats.expense - stats.transferOut;
  const projectedNet = net + stats.pendingIncome - stats.pendingExpense;
  const hasPending = stats.pendingIncome > 0 || stats.pendingExpense > 0;
  const netClass =
    net > 0
      ? "text-[var(--color-success)]"
      : net < 0
        ? "text-[var(--color-danger)]"
        : "text-[var(--color-foreground)]";
  return (
    <div className="flex flex-col gap-2 lg:grid lg:grid-flow-col lg:auto-cols-fr lg:gap-x-4 lg:gap-y-0">
      <Stat
        label="Net"
        value={formatCurrency(net)}
        sub={
          showPending && hasPending
            ? `≈ ${formatCurrency(projectedNet)} projected`
            : undefined
        }
        className={netClass}
      />
      <Stat
        label="Income"
        value={formatCurrency(stats.income)}
        sub={
          showPending && stats.pendingIncome > 0
            ? `+${formatCurrency(stats.pendingIncome)} pending`
            : undefined
        }
        className="text-[var(--color-success)]"
      />
      <Stat
        label="Expense"
        value={formatCurrency(stats.expense)}
        sub={
          showPending && stats.pendingExpense > 0
            ? `+${formatCurrency(stats.pendingExpense)} pending`
            : undefined
        }
        className="text-[var(--color-danger)]"
      />
      {showTransfers && (
        <>
          <Stat
            label="Transfer in"
            value={formatCurrency(stats.transferIn)}
            className={
              stats.transferIn > 0 ? "text-[var(--color-success)]" : undefined
            }
          />
          <Stat
            label="Transfer out"
            value={formatCurrency(stats.transferOut)}
            className={
              stats.transferOut > 0 ? "text-[var(--color-danger)]" : undefined
            }
          />
        </>
      )}
      <Stat label="Count" value={`${stats.count} txns`} />
      <Stat label="Largest expense" value={formatCurrency(stats.largestExpense)} />
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
    <div className="flex min-w-0 items-baseline justify-between gap-3 lg:flex-col lg:items-start lg:justify-start lg:gap-0.5">
      <span className="shrink-0 text-xs text-[var(--color-muted-foreground)] lg:shrink">
        {label}
      </span>
      <div className="flex min-w-0 flex-col items-end lg:items-start">
        <span className={cn("truncate text-sm font-semibold", className)}>
          {value}
        </span>
        {sub && (
          <span className="truncate text-xs text-[var(--color-muted-foreground)]">
            {sub}
          </span>
        )}
      </div>
    </div>
  );
}
