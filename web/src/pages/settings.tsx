import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/input";
import { CurrencySelect } from "@/components/shared/currency-select";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { useTheme, type Theme } from "@/lib/hooks/use-theme";
import { cn } from "@/lib/utils/cn";

const THEME_OPTIONS: { value: Theme; label: string }[] = [
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark" },
  { value: "system", label: "System" },
];

export default function SettingsPage() {
  const { defaultCurrency, updateDefaultCurrency } = useCurrencies();
  const { theme, setTheme } = useTheme();
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
        <CardContent className="space-y-6">
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

          <div className="flex max-w-xs flex-col gap-1.5">
            <Label>Theme</Label>
            <div
              role="radiogroup"
              aria-label="Theme"
              className="inline-flex rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-muted)] p-0.5"
            >
              {THEME_OPTIONS.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  role="radio"
                  aria-checked={theme === option.value}
                  onClick={() => setTheme(option.value)}
                  className={cn(
                    "flex-1 rounded-[calc(var(--radius)-2px)] px-3 py-1.5 text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-ring)]",
                    theme === option.value
                      ? "bg-[var(--color-card)] text-[var(--color-foreground)] shadow-sm"
                      : "text-[var(--color-muted-foreground)] hover:text-[var(--color-foreground)]",
                  )}
                >
                  {option.label}
                </button>
              ))}
            </div>
            <p className="text-xs text-[var(--color-muted-foreground)]">
              &quot;System&quot; follows your device&apos;s appearance setting.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
