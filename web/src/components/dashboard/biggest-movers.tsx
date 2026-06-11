import { TrendingUp } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import type { SpendingDelta } from "@/lib/utils/spending-delta";

interface Props {
  deltas: SpendingDelta[];
}

/**
 * Compact "what jumped this month?" card: the categories whose spend rose the
 * most versus last month. `deltas` arrives sorted by biggest increase first, so
 * we just take the leaders that actually went up.
 */
export function BiggestMoversCard({ deltas }: Props) {
  const { defaultCurrency } = useCurrencies();
  const movers = deltas.filter((d) => d.delta > 0).slice(0, 5);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Biggest Movers</CardTitle>
      </CardHeader>
      <CardContent>
        {movers.length === 0 ? (
          <EmptyState
            title="No increases"
            description="No category is spending more than last month."
          />
        ) : (
          <div className="flex flex-col gap-3">
            {movers.map((m) => (
              <div
                key={m.category_id}
                className="flex items-center justify-between gap-2 text-sm"
              >
                <span className="flex min-w-0 items-center gap-2">
                  <span className="shrink-0">{m.icon ?? "📊"}</span>
                  <span className="truncate font-medium">{m.category_name}</span>
                </span>
                <span className="flex shrink-0 items-center gap-1.5 text-[var(--color-danger)]">
                  <TrendingUp className="h-3.5 w-3.5" />
                  <span className="text-nowrap font-semibold">
                    +{formatCurrency(m.delta, defaultCurrency)}
                  </span>
                  <span className="text-nowrap text-xs">
                    {m.isNew
                      ? "new"
                      : m.deltaPct != null
                        ? `▲${Math.abs(Math.round(m.deltaPct))}%`
                        : ""}
                  </span>
                </span>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
