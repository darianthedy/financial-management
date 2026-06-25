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
import {
  formatCurrency,
  toDisplayAmount,
  currencyDecimals,
  getAppCurrency,
} from "@/lib/utils/currency";
import { monthDateBounds, todayIso, yearMonthOf } from "@/lib/utils/date";
import type { FixedExpenseWithStatus } from "@/lib/hooks/use-fixed-expenses";

interface Props {
  fixedExpense: FixedExpenseWithStatus;
  onEdit?: () => void;
  onRemove?: () => void;
}

export function FixedExpenseRow({ fixedExpense, onEdit, onRemove }: Props) {
  const navigate = useNavigate();
  const { id, name, amount, year_month, paid } = fixedExpense;

  // Pre-link a new transaction to this fixed expense. The date must fall in the
  // expense's month so the form lists it as a linkable option (the picker is
  // scoped to the date's month) and pre-selects it: use today when it's already
  // in that month, otherwise fall back to the month's first day. Prefilling the
  // amount saves retyping the expense's known cost; it's converted to display
  // units here (the form's field is in display units) using the same currency
  // registry that already formats this row's amount.
  function addTransaction() {
    const today = todayIso();
    const date = yearMonthOf(today) === year_month ? today : `${year_month}-01`;
    const displayAmount = toDisplayAmount(
      amount,
      currencyDecimals(getAppCurrency()),
    );
    navigate(
      `/transactions/new?fixedExpenseId=${id}&date=${date}&amount=${displayAmount}`,
    );
  }

  // Jump to the transaction list pre-filtered to this fixed expense (matched by
  // name) AND scoped to this expense's own month, so it shows the payment this
  // month's row tracks rather than every month's.
  function viewTransactions() {
    const { from, to } = monthDateBounds(year_month);
    navigate(
      `/transactions?fixed=${encodeURIComponent(name)}&from=${from}&to=${to}`,
    );
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
                // The menu renders in a portal but React events still bubble up
                // the component tree to the Card's onClick (which navigates to
                // the transactions list). Contain clicks so menu actions like
                // Edit aren't overridden by that navigation.
                onClick={(e) => e.stopPropagation()}
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
