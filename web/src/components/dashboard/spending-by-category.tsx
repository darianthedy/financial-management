import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, Legend } from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import type { SpendingByCategory } from "@/lib/types/database";

const DEFAULT_COLORS = [
  "#6366f1","#f59e0b","#10b981","#ef4444","#3b82f6","#8b5cf6","#ec4899","#14b8a6",
];

interface Props {
  data: SpendingByCategory[];
}

export function SpendingByCategoryCard({ data }: Props) {
  const { defaultCurrency } = useCurrencies();

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

  const chartData = data.map((d, i) => ({
    name: d.category_name,
    value: d.total_amount,
    color: d.color ?? DEFAULT_COLORS[i % DEFAULT_COLORS.length],
    icon: d.icon,
  }));

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
              formatter={(value, entry: any) =>
                `${entry.payload.icon ?? ""} ${value}`
              }
            />
          </PieChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
