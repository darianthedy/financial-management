import {
  MoreVertical,
  Pencil,
  Trash2,
  Play,
  Pause,
} from "lucide-react";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/misc";
import { formatSignedCurrency } from "@/lib/utils/currency";
import { formatDate } from "@/lib/utils/date";
import { cn } from "@/lib/utils/cn";
import type { ScheduledTransactionWithAccount } from "@/lib/hooks/use-scheduled-transactions";

interface Props {
  scheduled: ScheduledTransactionWithAccount;
  onEdit?: () => void;
  onToggleActive?: () => void;
  onRemove?: () => void;
}

export function ScheduledCard({
  scheduled,
  onEdit,
  onToggleActive,
  onRemove,
}: Props) {
  const { type, amount, description, next_due_date, is_active } = scheduled;
  const sign = type === "income" ? 1 : -1;
  const title = description?.trim() || (type === "income" ? "Income" : "Expense");
  const accountName = scheduled.accounts?.name ?? "?";

  return (
    <Card className={cn(!is_active && "opacity-60")}>
      <CardContent className="flex flex-col gap-3 p-4">
        <div className="flex items-start justify-between gap-2">
          <div className="flex min-w-0 flex-col gap-1">
            <span className="truncate font-medium">{title}</span>
            <span className="truncate text-xs text-[var(--color-muted-foreground)]">
              {accountName}
            </span>
          </div>
          <span
            className={cn(
              "shrink-0 text-nowrap font-semibold",
              type === "income"
                ? "text-[var(--color-success)]"
                : "text-[var(--color-danger)]",
            )}
          >
            {formatSignedCurrency(amount, sign)}
          </span>
          <DropdownMenu.Root>
            <DropdownMenu.Trigger
              className="rounded p-1 hover:bg-[var(--color-muted)]"
              aria-label="Scheduled transaction actions"
            >
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
                  className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm outline-none data-[highlighted]:bg-[var(--color-muted)]"
                  onSelect={() => onToggleActive?.()}
                >
                  {is_active ? (
                    <>
                      <Pause className="h-4 w-4" /> Pause
                    </>
                  ) : (
                    <>
                      <Play className="h-4 w-4" /> Resume
                    </>
                  )}
                </DropdownMenu.Item>
                <DropdownMenu.Item
                  className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm text-[var(--color-danger)] outline-none data-[highlighted]:bg-[var(--color-muted)]"
                  onSelect={() => onRemove?.()}
                >
                  <Trash2 className="h-4 w-4" /> Delete
                </DropdownMenu.Item>
              </DropdownMenu.Content>
            </DropdownMenu.Portal>
          </DropdownMenu.Root>
        </div>

        <div className="flex items-center justify-between gap-2 text-sm">
          <span className="text-[var(--color-muted-foreground)]">
            {is_active ? "Next" : "Paused, next"} {formatDate(next_due_date)}
          </span>
          <Badge>Monthly</Badge>
        </div>
      </CardContent>
    </Card>
  );
}
