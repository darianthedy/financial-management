import { useNavigate } from "react-router-dom";
import {
  MoreVertical,
  Pencil,
  Trash2,
  Check,
  ArrowLeftRight,
} from "lucide-react";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { Card, CardContent } from "@/components/ui/card";
import { formatCurrency } from "@/lib/utils/currency";
import { cn } from "@/lib/utils/cn";
import type { FixedExpenseWithStatus } from "@/lib/hooks/use-fixed-expenses";

interface Props {
  fixedExpense: FixedExpenseWithStatus;
  onEdit?: () => void;
  onRemove?: () => void;
}

export function FixedExpenseRow({ fixedExpense, onEdit, onRemove }: Props) {
  const navigate = useNavigate();
  const { id, name, amount, year_month, paid } = fixedExpense;

  // Pre-link a new transaction to this fixed expense. Dating it in the expense's
  // month makes the transaction form list it as a linkable option (the picker
  // is scoped to the date's month) and pre-selects it.
  function addTransaction() {
    navigate(`/transactions/new?fixedExpenseId=${id}&date=${year_month}-01`);
  }

  return (
    <Card>
      <CardContent className="flex flex-col gap-3 p-4">
        <div className="flex items-start justify-between gap-2">
          <span className="min-w-0 truncate font-medium">{name}</span>
          <span className="shrink-0 text-nowrap font-semibold">
            {formatCurrency(amount)}
          </span>
          <DropdownMenu.Root>
            <DropdownMenu.Trigger
              className="rounded p-1 hover:bg-[var(--color-muted)]"
              aria-label="Fixed expense actions"
            >
              <MoreVertical className="h-4 w-4 text-[var(--color-muted-foreground)]" />
            </DropdownMenu.Trigger>
            <DropdownMenu.Portal>
              <DropdownMenu.Content
                sideOffset={4}
                align="end"
                className="z-50 min-w-44 rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-card)] p-1 shadow-md"
              >
                <DropdownMenu.Item
                  className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm outline-none data-[highlighted]:bg-[var(--color-muted)]"
                  onSelect={() => addTransaction()}
                >
                  <ArrowLeftRight className="h-4 w-4" /> Add transaction
                </DropdownMenu.Item>
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
                  <Trash2 className="h-4 w-4" /> Delete
                </DropdownMenu.Item>
              </DropdownMenu.Content>
            </DropdownMenu.Portal>
          </DropdownMenu.Root>
        </div>

        <div>
          <span
            className={cn(
              "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium",
              paid
                ? "bg-[color-mix(in_srgb,var(--color-success)_15%,transparent)] text-[var(--color-success)]"
                : "border border-[var(--color-border)] bg-[var(--color-muted)] text-[var(--color-muted-foreground)]",
            )}
          >
            {paid && <Check className="h-3 w-3" />}
            {paid ? "Paid" : "Unpaid"}
          </span>
        </div>
      </CardContent>
    </Card>
  );
}
