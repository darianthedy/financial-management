import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/input";
import { CurrencySelect } from "@/components/shared/currency-select";
import { useCurrencies } from "@/lib/hooks/use-currencies";

export default function SettingsPage() {
  const { defaultCurrency, updateDefaultCurrency } = useCurrencies();
  const [error, setError] = useState("");

  async function handleCurrencyChange(code: string) {
    setError("");
    try {
      await updateDefaultCurrency(code);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to save currency");
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
            {error && (
              <p className="text-xs text-[var(--color-danger)]">{error}</p>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
