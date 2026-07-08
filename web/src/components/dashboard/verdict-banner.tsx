import { CheckCircle2, AlertTriangle } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { formatCurrency } from "@/lib/utils/currency";
import { cn } from "@/lib/utils/cn";
import type { BudgetProgress } from "@/lib/types/database";
import type { FixedExpenseWithStatus } from "@/lib/hooks/use-fixed-expenses";

interface Props {
  budgets: BudgetProgress[];
  fixedExpenses: FixedExpenseWithStatus[];
}

type Tone = "success" | "danger" | "warning";

const TONE_TEXT: Record<Tone, string> = {
  success: "text-[var(--color-success)]",
  danger: "text-[var(--color-danger)]",
  warning: "text-[var(--color-warning)]",
};
const TONE_BORDER: Record<Tone, string> = {
  success: "border-l-[var(--color-success)]",
  danger: "border-l-[var(--color-danger)]",
  warning: "border-l-[var(--color-warning)]",
};

/** One at-a-glance status line: an icon, a colored label, and a muted detail. */
interface StatusRow {
  tone: Tone;
  label: string;
  detail: string;
}

/**
 * The at-a-glance answer to "am I on track?". Renders one compact status line
 * per domain — budgets, and (when they diverge) paid fixed expenses — so the two
 * read as parallel statuses rather than one buried under the other. The card's
 * left border takes the most severe tone across the rows.
 */
export function VerdictBanner({ budgets, fixedExpenses }: Props) {
  const overspent = budgets.filter((b) => b.remaining < 0);
  const overage = overspent.reduce((sum, b) => sum + Math.abs(b.remaining), 0);

  // Paid fixed expenses where what was actually paid differs from the plan.
  const paidWithDiff = fixedExpenses.filter(
    (f) => f.paid && f.paid_total !== f.amount,
  );
  const netDiff = paidWithDiff.reduce(
    (sum, f) => sum + (f.paid_total - f.amount),
    0,
  );

  const rows: StatusRow[] = [];

  if (budgets.length > 0) {
    rows.push(
      overspent.length > 0
        ? {
            tone: "danger",
            label: `Overspending in ${overspent.length} budget${overspent.length === 1 ? "" : "s"}`,
            detail: `−${formatCurrency(overage)} over`,
          }
        : {
            tone: "success",
            label: "Budgets on track",
            detail: `all ${budgets.length} within target`,
          },
    );
  }

  if (paidWithDiff.length > 0) {
    rows.push({
      tone: "warning",
      label: `${paidWithDiff.length} fixed expense${paidWithDiff.length === 1 ? "" : "s"} off plan`,
      detail:
        netDiff === 0
          ? "amounts differ"
          : `net ${netDiff > 0 ? "+" : "−"}${formatCurrency(Math.abs(netDiff))}`,
    });
  }

  if (rows.length === 0) return null;

  // Border reflects the most severe row: danger > warning > success.
  const borderTone: Tone = rows.some((r) => r.tone === "danger")
    ? "danger"
    : rows.some((r) => r.tone === "warning")
      ? "warning"
      : "success";

  return (
    <Card className={cn("border-l-4", TONE_BORDER[borderTone])}>
      <CardContent className="flex flex-col gap-2 p-4">
        {rows.map((row, i) => (
          <div key={i} className="flex items-center gap-2.5">
            {row.tone === "success" ? (
              <CheckCircle2
                className={cn("h-5 w-5 shrink-0", TONE_TEXT[row.tone])}
              />
            ) : (
              <AlertTriangle
                className={cn("h-5 w-5 shrink-0", TONE_TEXT[row.tone])}
              />
            )}
            <p className="min-w-0 truncate text-sm">
              <span className={cn("font-semibold", TONE_TEXT[row.tone])}>
                {row.label}
              </span>
              <span className="text-[var(--color-muted-foreground)]">
                {" · "}
                {row.detail}
              </span>
            </p>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
