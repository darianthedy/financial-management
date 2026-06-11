import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, Legend } from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { cn } from "@/lib/utils/cn";
import type { SpendingByCategory } from "@/lib/types/database";
import type { SpendingDelta } from "@/lib/utils/spending-delta";

const DEFAULT_COLORS = [
  "#6366f1","#f59e0b","#10b981","#ef4444","#3b82f6","#8b5cf6","#ec4899","#14b8a6",
];

interface Props {
  data: SpendingByCategory[];
  deltas?: SpendingDelta[];
}

export function SpendingByCategoryCard({ data, deltas = [] }: Props) {
  const { defaultCurrency } = useCurrencies();
  const deltaById = new Map(deltas.map((d) => [d.category_id, d]));

  if (data.length === 0) {
    return (
      <Card>
        <CardHeader><CardTitle>Spending by Category</CardTitle></CardHeader>
        <CardContent>
          <EmptyState title="No categorized expenses" description="Tag your expenses with categories to see a breakdown." />
        </CardContent>
      </Card>
    );
  }

  const chartData = data.map((d, i) => {
    const delta = deltaById.get(d.category_id);
    return {
      name: d.category_name,
      value: d.total_amount,
      color: d.color ?? DEFAULT_COLORS[i % DEFAULT_COLORS.length],
      icon: d.icon,
      deltaPct: delta?.deltaPct ?? null,
      isNew: delta?.isNew ?? false,
    };
  });

  return (
    <Card>
      <CardHeader><CardTitle>Spending by Category</CardTitle></CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={220}>
          <PieChart>
            <Pie
              data={chartData}
              dataKey="value"
              nameKey="name"
              cx="50%"
              cy="50%"
              innerRadius={60}
              outerRadius={90}
            >
              {chartData.map((entry, i) => (
                <Cell key={i} fill={entry.color} />
              ))}
            </Pie>
            <Tooltip
              formatter={(value) => formatCurrency(value as number, defaultCurrency)}
            />
            <Legend
              formatter={(value, entry: any) => {
                const p = entry.payload;
                const pct: number | null = p.deltaPct;
                return (
                  <span className="text-xs">
                    {p.icon ? `${p.icon} ` : ""}
                    {value}
                    {p.isNew ? (
                      <span className="ml-1 text-[var(--color-muted-foreground)]">
                        new
                      </span>
                    ) : (
                      pct != null &&
                      Math.round(pct) !== 0 && (
                        <span
                          className={cn(
                            "ml-1",
                            pct > 0
                              ? "text-[var(--color-danger)]"
                              : "text-[var(--color-success)]",
                          )}
                        >
                          {pct > 0 ? "▲" : "▼"}
                          {Math.abs(Math.round(pct))}%
                        </span>
                      )
                    )}
                  </span>
                );
              }}
            />
          </PieChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
