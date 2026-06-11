import { useNavigate } from "react-router-dom";
import {
  MoreVertical,
  Pencil,
  Trash2,
  CheckCircle2,
  Clock,
  ArrowLeftRight,
} from "lucide-react";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { Card, CardContent } from "@/components/ui/card";
import { formatCurrency } from "@/lib/utils/currency";
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

  // Jump to the transaction list pre-filtered to this fixed expense (matched by
  // name, across months — mirrors the filter bar's fixed-expense option).
  function viewTransactions() {
    navigate(`/transactions?fixed=${encodeURIComponent(name)}`);
  }

  return (
    <Card
      className="cursor-pointer transition-shadow hover:shadow-md"
      onClick={viewTransactions}
    >
      <CardContent className="flex items-center justify-between gap-3 p-4">
        {/* Left: paid/unpaid icon + name, inline to keep the row compact. */}
        <div className="flex min-w-0 items-center gap-2">
          {paid ? (
            <CheckCircle2
              className="h-4 w-4 shrink-0 text-[var(--color-success)]"
              aria-label="Paid"
            />
          ) : (
            <Clock
              className="h-4 w-4 shrink-0 text-[var(--color-muted-foreground)]"
              aria-label="Unpaid"
            />
          )}
          <span className="truncate font-medium">{name}</span>
        </div>

        {/* Right: amount + actions menu. */}
        <div className="flex shrink-0 items-center gap-1">
          <span className="text-nowrap font-semibold">
            {formatCurrency(amount)}
          </span>
          <DropdownMenu.Root>
            <DropdownMenu.Trigger
              className="-mr-1 rounded p-1 hover:bg-[var(--color-muted)]"
              aria-label="Fixed expense actions"
              onClick={(e) => e.stopPropagation()}
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
      </CardContent>
    </Card>
  );
}
