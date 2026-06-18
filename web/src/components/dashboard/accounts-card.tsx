import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { AccountAvatar } from "@/components/accounts/account-avatar";
import { AmountColumn } from "@/components/shared/amount-column";
import { widestCurrencyNumber } from "@/lib/utils/currency";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { cn } from "@/lib/utils/cn";
import type { AccountMonthBalance } from "@/lib/hooks/use-dashboard";

interface Props {
  accounts: AccountMonthBalance[];
}

/**
 * Each account's latest balance for the selected month — the end-of-month
 * figure from the monthly balance ledger — plus their combined total. Lets the
 * dashboard answer "how much do I have?" right under the budget verdict.
 */
export function AccountsCard({ accounts }: Props) {
  const { defaultCurrency } = useCurrencies();
  const total = accounts.reduce((sum, a) => sum + a.balance, 0);
  const widestAmount = widestCurrencyNumber(
    [total, ...accounts.map((a) => a.balance)],
    defaultCurrency,
  );

  return (
    <Card>
      <CardHeader>
        <CardTitle>Accounts</CardTitle>
      </CardHeader>
      <CardContent>
        {accounts.length === 0 ? (
          <EmptyState
            title="No accounts yet"
            description="Add an account to track your balance here."
          />
        ) : (
          <div className="flex flex-col gap-3">
            <div className="flex items-baseline justify-between">
              <span className="text-sm text-[var(--color-muted-foreground)]">
                Total balance
              </span>
              <AmountColumn
                minorUnits={total}
                currency={defaultCurrency}
                widestNumber={widestAmount}
                className={cn(
                  "text-nowrap text-sm font-semibold",
                  total < 0 && "text-[var(--color-danger)]",
                )}
              />
            </div>
            <div className="flex flex-col gap-2">
              {accounts.map((account) => (
                <div
                  key={account.id}
                  className="flex items-center justify-between gap-2 text-sm"
                >
                  <span className="flex min-w-0 items-center gap-2">
                    <AccountAvatar
                      type={account.type}
                      imageUrl={account.image_url}
                      name={account.name}
                      className="h-7 w-7"
                      iconClassName="h-4 w-4"
                    />
                    <span className="truncate font-medium">{account.name}</span>
                  </span>
                  <AmountColumn
                    minorUnits={account.balance}
                    currency={defaultCurrency}
                    widestNumber={widestAmount}
                    className={cn(
                      "text-nowrap font-semibold",
                      account.balance < 0 && "text-[var(--color-danger)]",
                    )}
                  />
                </div>
              ))}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
