import { Link } from "react-router-dom";
import { ArrowRight, ArrowDownLeft, ArrowUpRight, ArrowLeftRight } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
import { formatDate } from "@/lib/utils/date";
import { cn } from "@/lib/utils/cn";
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
              const isIncome = txn.type === "income";
              const isTransfer = txn.type === "transfer";
              const Icon = isTransfer ? ArrowLeftRight : isIncome ? ArrowDownLeft : ArrowUpRight;
              const amountColor = isTransfer
                ? "text-[var(--color-foreground)]"
                : isIncome
                  ? "text-[var(--color-success)]"
                  : "text-[var(--color-danger)]";
              const display = formatCurrency(txn.amount, txn.currency);
              return (
                <div key={txn.id} className="flex items-center gap-3 py-2.5">
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[var(--color-muted)]">
                    <Icon className="h-4 w-4 text-[var(--color-muted-foreground)]" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">
                      {txn.description || txn.type}
                    </p>
                    <p className="truncate text-xs text-[var(--color-muted-foreground)]">
                      {txn.accounts?.name} · {formatDate(txn.date)}
                    </p>
                  </div>
                  <span className={cn("text-nowrap text-sm font-semibold", amountColor)}>
                    {display}
                  </span>
                </div>
              );
            })}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
