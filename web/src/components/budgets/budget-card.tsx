import { MoreVertical, Pencil, Trash2 } from "lucide-react";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
import type { BudgetProgress } from "@/lib/types/database";
import { cn } from "@/lib/utils/cn";

interface Props {
  budget: BudgetProgress;
  onEdit?: () => void;
  onRemove?: () => void;
}

export function BudgetCard({ budget, onEdit, onRemove }: Props) {
  const { currency, effective_amount, spent, remaining, carry_over_amount } =
    budget;
  const overspent = remaining < 0;

  // Bar fills with net spend against the effective amount (periodic + carry-in).
  // A non-positive effective amount (deep carried-over overspend) reads as full.
  const pct =
    effective_amount > 0
      ? Math.min(100, Math.max(0, (spent / effective_amount) * 100))
      : spent > 0
        ? 100
        : 0;

  return (
    <Card>
      <CardContent className="flex flex-col gap-3 p-4">
        <div className="flex items-start justify-between gap-2">
          <div className="flex min-w-0 flex-col gap-1">
            <span className="truncate font-medium">{budget.budget_name}</span>
            <div className="flex flex-wrap items-center gap-2">
              <Badge>{currency}</Badge>
              {carry_over_amount !== 0 && (
                <span
                  className={cn(
                    "text-xs",
                    carry_over_amount > 0
                      ? "text-[var(--color-success)]"
                      : "text-[var(--color-danger)]",
                  )}
                >
                  {carry_over_amount > 0
                    ? `+${formatCurrency(carry_over_amount, currency)} carried over`
                    : `${formatCurrency(carry_over_amount, currency)} overspent`}
                </span>
              )}
            </div>
          </div>
          <DropdownMenu.Root>
            <DropdownMenu.Trigger className="rounded p-1 hover:bg-[var(--color-muted)]">
              <MoreVertical className="h-4 w-4 text-[var(--color-muted-foreground)]" />
            </DropdownMenu.Trigger>
            <DropdownMenu.Portal>
              <DropdownMenu.Content
                sideOffset={4}
                align="end"
                className="z-50 min-w-36 rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-card)] p-1 shadow-md"
              >
                <DropdownMenu.Item
                  className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm outline-none data-[highlighted]:bg-[var(--color-muted)]"
                  onSelect={() => onEdit?.()}
                >
                  <Pencil className="h-4 w-4" /> Edit
                </DropdownMenu.Item>
                <DropdownMenu.Item
                  className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm text-[var(--color-danger)] outline-none data-[highlighted]:bg-[var(--color-muted)]"
                  onSelect={() => onRemove?.()}
                >
                  <Trash2 className="h-4 w-4" /> Remove
                </DropdownMenu.Item>
              </DropdownMenu.Content>
            </DropdownMenu.Portal>
          </DropdownMenu.Root>
        </div>

        <div className="h-2 w-full overflow-hidden rounded-full bg-[var(--color-muted)]">
          <div
            className={cn(
              "h-full rounded-full transition-all",
              overspent
                ? "bg-[var(--color-danger)]"
                : "bg-[var(--color-primary)]",
            )}
            style={{ width: `${pct}%` }}
          />
        </div>

        <div className="flex items-center justify-between text-sm">
          <span className="text-[var(--color-muted-foreground)]">
            {formatCurrency(spent, currency)} of{" "}
            {formatCurrency(effective_amount, currency)}
          </span>
          <span
            className={cn(
              "text-nowrap font-medium",
              overspent
                ? "text-[var(--color-danger)]"
                : "text-[var(--color-foreground)]",
            )}
          >
            {overspent
              ? `${formatCurrency(Math.abs(remaining), currency)} over`
              : `${formatCurrency(remaining, currency)} left`}
          </span>
        </div>
      </CardContent>
    </Card>
  );
}
