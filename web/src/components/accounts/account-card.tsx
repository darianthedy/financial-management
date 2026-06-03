import { MoreVertical, Pencil, Archive } from "lucide-react";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/misc";
import { accountTypeIcon, accountTypeLabel } from "@/lib/account-types";
import { formatCurrency } from "@/lib/utils/currency";
import type { AccountWithBalance } from "@/lib/hooks/use-accounts";
import { cn } from "@/lib/utils/cn";

interface Props {
  account: AccountWithBalance;
  onClick?: () => void;
  onEdit?: () => void;
  onArchive?: () => void;
}

export function AccountCard({ account, onClick, onEdit, onArchive }: Props) {
  const Icon = accountTypeIcon(account.type);
  const balance = formatCurrency(account.current_balance, account.currency);
  const isNegative = account.current_balance < 0;

  return (
    <Card
      className="relative cursor-pointer transition-shadow hover:shadow-md"
      onClick={onClick}
    >
      <CardContent className="flex items-start gap-3 p-4">
        <div className="mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[var(--color-muted)]">
          <Icon className="h-5 w-5 text-[var(--color-muted-foreground)]" />
        </div>
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          <span className="truncate font-medium">{account.name}</span>
          <Badge>{accountTypeLabel(account.type)}</Badge>
        </div>
        <div className="flex flex-col items-end gap-1">
          <span
            className={cn(
              "text-nowrap font-semibold",
              isNegative
                ? "text-[var(--color-danger)]"
                : "text-[var(--color-foreground)]",
            )}
          >
            {balance}
          </span>
          <DropdownMenu.Root>
            <DropdownMenu.Trigger
              className="rounded p-1 hover:bg-[var(--color-muted)]"
              onClick={(e) => e.stopPropagation()}
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
                  className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm text-[var(--color-danger)] outline-none data-[highlighted]:bg-[var(--color-muted)]"
                  onSelect={() => onArchive?.()}
                >
                  <Archive className="h-4 w-4" /> Archive
                </DropdownMenu.Item>
              </DropdownMenu.Content>
            </DropdownMenu.Portal>
          </DropdownMenu.Root>
        </div>
      </CardContent>
    </Card>
  );
}
