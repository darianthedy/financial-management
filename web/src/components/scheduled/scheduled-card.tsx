import {
  MoreVertical,
  Pencil,
  Trash2,
  Play,
  Pause,
  CalendarClock,
} from "lucide-react";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { cn } from "@/lib/utils/cn";
import { formatCurrency } from "@/lib/utils/currency";
import { formatDate } from "@/lib/utils/date";
import {
  AccountAvatar,
  TransactionChips,
  amountColor as amountColorFor,
  deriveTitle,
  type TxnDisplay,
} from "@/components/transactions/transaction-display";
import type { Category, Tag } from "@/lib/types/database";
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
  const { type, amount, is_active, next_due_date } = scheduled;
  const accountName = scheduled.accounts?.name ?? "?";

  // Map the scheduled row onto the shared transaction-display shape so the row
  // renders identically to the transactions list (avatar, title, subtitle,
  // category/tag chips). The scheduled row only carries a subset of a category
  // (no user_id/icon/created_at) and tags (id/name) — the display helpers read
  // only id/name/color, so the cast is safe.
  const display: TxnDisplay = {
    type,
    description: scheduled.description,
    accounts: scheduled.accounts,
    transfer_accounts: null,
    category: scheduled.category_id
      ? ({
          id: scheduled.category_id,
          name: scheduled.category?.name ?? "",
          color: scheduled.category?.color ?? null,
        } as unknown as Category)
      : null,
    tags: scheduled.tags as unknown as Tag[],
    budget: scheduled.budget_name ? { name: scheduled.budget_name } : null,
    fixedExpense: scheduled.fixed_expense_name
      ? { name: scheduled.fixed_expense_name }
      : null,
  };

  const { title, usedCategoryId, usedFixedExpense, titleIsDescription } =
    deriveTitle(display);
  const subtitle = titleIsDescription ? null : scheduled.description;

  return (
    <div
      className={cn(
        "flex items-center gap-3 rounded-[var(--radius)] px-3 py-3 transition-colors hover:bg-[var(--color-muted)]",
        !is_active && "opacity-60",
      )}
    >
      <AccountAvatar
        name={accountName}
        type={type}
        imageUrl={scheduled.accounts?.image_url}
      />

      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="truncate text-sm font-semibold">{title}</span>
        {subtitle && (
          <span className="truncate text-xs text-[var(--color-muted-foreground)]">
            {subtitle}
          </span>
        )}
        <TransactionChips
          txn={display}
          excludeCategoryId={usedCategoryId}
          excludeFixedExpense={usedFixedExpense}
        />
        {/* Footer: when this schedule next fires (or that it's paused). */}
        <span className="inline-flex items-center gap-1 pt-0.5 text-xs text-[var(--color-muted-foreground)]">
          <CalendarClock className="h-3 w-3 shrink-0" />
          {is_active ? "Next" : "Paused · next"} {formatDate(next_due_date)}
        </span>
      </div>

      <span
        className={cn(
          "shrink-0 text-nowrap text-sm font-semibold",
          amountColorFor(type),
        )}
      >
        {formatCurrency(amount)}
      </span>

      <DropdownMenu.Root>
        <DropdownMenu.Trigger
          className="rounded p-1 hover:bg-[var(--color-card)]"
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
  );
}
