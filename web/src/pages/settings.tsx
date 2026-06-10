import { useEffect, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { CurrencySelect } from "@/components/shared/currency-select";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import {
  useAccounts,
  fetchDefaultAccountId,
  updateDefaultAccountId,
} from "@/lib/hooks/use-accounts";

// Radix Select disallows "" as a value, so use a sentinel for "no default".
const ACCOUNT_NONE = "__none__";

export default function SettingsPage() {
  const { defaultCurrency, updateDefaultCurrency } = useCurrencies();
  const { accounts } = useAccounts();
  const [defaultAccountId, setDefaultAccountId] = useState<string | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    fetchDefaultAccountId().then(setDefaultAccountId);
  }, []);

  async function handleCurrencyChange(code: string) {
    setError("");
    try {
      await updateDefaultCurrency(code);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to save currency");
    }
  }

  async function handleDefaultAccountChange(value: string) {
    setError("");
    const accountId = value === ACCOUNT_NONE ? null : value;
    const previous = defaultAccountId;
    setDefaultAccountId(accountId);
    try {
      await updateDefaultAccountId(accountId);
    } catch (e) {
      setDefaultAccountId(previous);
      setError(e instanceof Error ? e.message : "Failed to save default account");
    }
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Settings</h1>

      <Card>
        <CardHeader>
          <CardTitle>Preferences</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex max-w-xs flex-col gap-1.5">
            <Label htmlFor="currency">Currency</Label>
            <CurrencySelect
              id="currency"
              value={defaultCurrency}
              onChange={handleCurrencyChange}
            />
            <p className="text-xs text-[var(--color-muted-foreground)]">
              Used for all new accounts, budgets, and transactions.
            </p>
          </div>

          <div className="mt-5 flex max-w-xs flex-col gap-1.5">
            <Label htmlFor="default_account">Default account</Label>
            <Select
              value={defaultAccountId ?? ACCOUNT_NONE}
              onValueChange={handleDefaultAccountChange}
            >
              <SelectTrigger id="default_account">
                <SelectValue placeholder="No default" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={ACCOUNT_NONE}>No default</SelectItem>
                {accounts.map((a) => (
                  <SelectItem key={a.id} value={a.id}>
                    {a.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="text-xs text-[var(--color-muted-foreground)]">
              Pre-selected when you add a new transaction.
            </p>
          </div>

          {error && (
            <p className="mt-3 text-xs text-[var(--color-danger)]">{error}</p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
