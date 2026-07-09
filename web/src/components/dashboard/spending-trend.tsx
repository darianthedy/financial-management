import {
  Bar,
  BarChart,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
import { formatYearMonth, formatYearMonthShort } from "@/lib/utils/date";
import { cn } from "@/lib/utils/cn";
import type { CashflowTrendPoint } from "@/lib/hooks/use-cashflow-trend";

interface Props {
  trend: CashflowTrendPoint[];
  /** The month the dashboard is focused on — emphasized in the chart. */
  selectedYearMonth: string;
  /** Jump the whole dashboard to a month when its column is clicked. */
  onSelectMonth: (yearMonth: string) => void;
}

// Identity colors follow the app's semantic language (matching the Cashflow
// card): income = success, expense = danger. Kept as CSS vars so light/dark
// theming stays automatic. Series identity is carried by the legend and by each
// bar's fixed position within its month group, never by color alone.
const INCOME_COLOR = "var(--color-success)";
const EXPENSE_COLOR = "var(--color-danger)";

interface TooltipDatum {
  payload: CashflowTrendPoint;
}

function TrendTooltip({
  active,
  payload,
}: {
  active?: boolean;
  payload?: TooltipDatum[];
}) {
  if (!active || !payload?.length) return null;
  const d = payload[0].payload;
  const positiveNet = d.net >= 0;
  return (
    <div className="rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-card)] p-2.5 text-xs shadow-md">
      <p className="mb-1.5 font-medium">{formatYearMonth(d.year_month)}</p>
      <div className="flex flex-col gap-1">
        <Row label="Income" color={INCOME_COLOR} value={d.total_income} />
        <Row label="Expenses" color={EXPENSE_COLOR} value={d.total_expense} />
        <div className="mt-0.5 flex items-baseline justify-between gap-6 border-t border-[var(--color-border)] pt-1">
          <span className="text-[var(--color-muted-foreground)]">Net</span>
          <span
            className={cn(
              "font-semibold tabular-nums",
              positiveNet
                ? "text-[var(--color-success)]"
                : "text-[var(--color-danger)]",
            )}
          >
            {d.net >= 0 ? "+" : "-"}
            {formatCurrency(Math.abs(d.net))}
          </span>
        </div>
      </div>
    </div>
  );
}

function Row({
  label,
  color,
  value,
}: {
  label: string;
  color: string;
  value: number;
}) {
  return (
    <div className="flex items-baseline justify-between gap-6">
      <span className="flex items-center gap-1.5 text-[var(--color-muted-foreground)]">
        <span
          aria-hidden
          className="inline-block h-2 w-2 rounded-[2px]"
          style={{ backgroundColor: color }}
        />
        {label}
      </span>
      <span className="tabular-nums">{formatCurrency(value)}</span>
    </div>
  );
}

/** Small color swatch + label; the always-present legend for the two series. */
function LegendSwatch({ label, color }: { label: string; color: string }) {
  return (
    <span className="flex items-center gap-1.5 text-xs text-[var(--color-muted-foreground)]">
      <span
        aria-hidden
        className="inline-block h-2.5 w-2.5 rounded-[2px]"
        style={{ backgroundColor: color }}
      />
      {label}
    </span>
  );
}

/**
 * Income vs expense across the trailing months, so the selected month reads in
 * context ("is this month unusual?"). The focused month's columns are at full
 * strength while the rest are dimmed, and clicking any month's columns navigates
 * the whole dashboard there. Net is surfaced in the hover tooltip. The first
 * real use of the charting library in the app.
 */
export function SpendingTrendCard({
  trend,
  selectedYearMonth,
  onSelectMonth,
}: Props) {
  const isEmpty = trend.every(
    (d) => d.total_income === 0 && d.total_expense === 0,
  );

  // Emphasize the focused month; recede the rest so the chart stays anchored to
  // the month navigator at the top of the dashboard.
  const opacityFor = (ym: string) => (ym === selectedYearMonth ? 1 : 0.4);

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between gap-2 space-y-0">
        <CardTitle>Spending Trend</CardTitle>
        <div className="flex items-center gap-3">
          <LegendSwatch label="Income" color={INCOME_COLOR} />
          <LegendSwatch label="Expenses" color={EXPENSE_COLOR} />
        </div>
      </CardHeader>
      <CardContent>
        {isEmpty ? (
          <EmptyState
            title="No activity yet"
            description="Income and expenses will chart here as you add transactions."
          />
        ) : (
          <div className="h-[180px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart
                data={trend}
                margin={{ top: 4, right: 4, bottom: 0, left: 4 }}
                barGap={2}
                barCategoryGap="24%"
                onClick={(state) => {
                  const ym = state?.activeLabel;
                  if (typeof ym === "string") onSelectMonth(ym);
                }}
              >
                <XAxis
                  dataKey="year_month"
                  tickFormatter={formatYearMonthShort}
                  tickLine={false}
                  axisLine={{ stroke: "var(--color-border)" }}
                  tick={{
                    fontSize: 12,
                    fill: "var(--color-muted-foreground)",
                  }}
                  interval={0}
                />
                {/* Hidden — bars share one currency scale; no gridlines keeps the
                    small card clean. */}
                <YAxis hide />
                <Tooltip
                  content={<TrendTooltip />}
                  cursor={{ fill: "var(--color-muted)", opacity: 0.5 }}
                />
                <Bar
                  dataKey="total_income"
                  name="Income"
                  fill={INCOME_COLOR}
                  radius={[3, 3, 0, 0]}
                  isAnimationActive={false}
                  className="cursor-pointer"
                >
                  {trend.map((d) => (
                    <Cell
                      key={d.year_month}
                      fillOpacity={opacityFor(d.year_month)}
                    />
                  ))}
                </Bar>
                <Bar
                  dataKey="total_expense"
                  name="Expenses"
                  fill={EXPENSE_COLOR}
                  radius={[3, 3, 0, 0]}
                  isAnimationActive={false}
                  className="cursor-pointer"
                >
                  {trend.map((d) => (
                    <Cell
                      key={d.year_month}
                      fillOpacity={opacityFor(d.year_month)}
                    />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
