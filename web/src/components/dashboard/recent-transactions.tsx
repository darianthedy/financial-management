import { Link } from "react-router-dom";
import { ArrowRight } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
import { formatDate } from "@/lib/utils/date";
import { cn } from "@/lib/utils/cn";
import {
  AccountAvatar,
  TransactionChips,
  amountColor as amountColorFor,
  deriveTitle,
} from "@/components/transactions/transaction-display";
import type { RecentTransaction } from "@/lib/hooks/use-dashboard";

interface Props {
  transactions: RecentTransaction[];
}

export function RecentTransactionsCard({ transactions }: Props) {
  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between">
        <CardTitle>Recent Transactions</CardTitle>
        <Link to="/transactions">
          <Button variant="ghost" size="sm">
            See all <ArrowRight className="ml-1 h-3 w-3" />
          </Button>
        </Link>
      </CardHeader>
      <CardContent>
        {transactions.length === 0 ? (
          <EmptyState title="No transactions yet" />
        ) : (
          <div className="divide-y divide-[var(--color-border)]">
            {transactions.map((txn) => {
              const { title, usedCategoryId, titleIsDescription } = deriveTitle(txn);
              const subtitle = titleIsDescription ? null : txn.description;
              return (
                <div key={txn.id} className="flex items-center gap-3 py-2.5">
                  <AccountAvatar
                    name={txn.accounts?.name ?? "?"}
                    type={txn.type}
                    imageUrl={txn.accounts?.image_url}
                    size="sm"
                  />
                  <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                    <p className="truncate text-sm font-semibold">{title}</p>
                    {subtitle && (
                      <p className="truncate text-xs text-[var(--color-muted-foreground)]">
                        {subtitle}
                      </p>
                    )}
                    <TransactionChips txn={txn} excludeCategoryId={usedCategoryId} />
                  </div>
                  <div className="flex shrink-0 flex-col items-end gap-1">
                    <span
                      className={cn(
                        "text-nowrap text-sm font-semibold",
                        amountColorFor(txn.type),
                      )}
                    >
                      {formatCurrency(txn.amount)}
                    </span>
                    <span className="text-xs text-[var(--color-muted-foreground)]">
                      {formatDate(txn.date)}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
