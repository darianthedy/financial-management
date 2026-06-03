import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatCurrency } from "@/lib/utils/currency";
import type { MonthlyCashflow } from "@/lib/types/database";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { cn } from "@/lib/utils/cn";

interface Props {
  cashflow: MonthlyCashflow | null;
}

export function CashflowCard({ cashflow }: Props) {
  const { defaultCurrency } = useCurrencies();

  const income = cashflow?.total_income ?? 0;
  const expense = cashflow?.total_expense ?? 0;
  const net = cashflow?.net ?? 0;

  const rows = [
    { label: "Income", value: income, color: "text-[var(--color-success)]" },
    { label: "Expenses", value: expense, color: "text-[var(--color-danger)]" },
    { label: "Net", value: net, color: net >= 0 ? "text-[var(--color-success)]" : "text-[var(--color-danger)]", bold: true },
  ];

  return (
    <Card>
      <CardHeader>
        <CardTitle>Cash Flow</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {rows.map((row) => (
          <div key={row.label} className={cn("flex items-center justify-between", row.bold && "border-t border-[var(--color-border)] pt-2")}>
            <span className="text-sm text-[var(--color-muted-foreground)]">{row.label}</span>
            <span className={cn("text-nowrap font-semibold overflow-hidden text-ellipsis max-w-[60%]", row.color)}>
              {formatCurrency(row.value, defaultCurrency)}
            </span>
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
