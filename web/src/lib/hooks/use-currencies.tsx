import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  type ReactNode,
} from "react";
import { supabase } from "@/lib/supabase/client";
import { registerCurrencyDecimals, setAppCurrency } from "@/lib/utils/currency";
import type { Currency } from "@/lib/types/database";

interface CurrencyContextValue {
  currencies: Currency[];
  defaultCurrency: string;
  decimalsFor: (code: string) => number;
  loading: boolean;
  /** Persist a new app-wide currency to user_settings and update state. */
  updateDefaultCurrency: (code: string) => Promise<void>;
}

const CurrencyContext = createContext<CurrencyContextValue | null>(null);

/**
 * Loads the currency list + the user's single app-wide currency once, and shares
 * them with every page. Mounted in AppLayout so changing the currency in Settings
 * propagates instantly to all mounted views.
 */
export function CurrencyProvider({ children }: { children: ReactNode }) {
  const [currencies, setCurrencies] = useState<Currency[]>([]);
  const [defaultCurrency, setDefaultCurrency] = useState("USD");
  const [loading, setLoading] = useState(true);

  const fetchCurrencies = useCallback(async () => {
    const { data } = await supabase.from("currencies").select("*").order("code");
    setCurrencies(data ?? []);
    // Feed the module-level registry so formatCurrency() resolves the correct
    // decimal places everywhere, including leaf components that don't use this hook.
    if (data) registerCurrencyDecimals(data);
  }, []);

  const fetchSettings = useCallback(async () => {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const { data } = await supabase
      .from("user_settings")
      .select("*")
      .eq("user_id", user.id)
      .maybeSingle();
    if (data?.default_currency) setDefaultCurrency(data.default_currency);
  }, []);

  useEffect(() => {
    Promise.all([fetchCurrencies(), fetchSettings()]).then(() =>
      setLoading(false),
    );
  }, [fetchCurrencies, fetchSettings]);

  // Currency is no longer stored per record, so formatCurrency() formats every
  // amount in this one currency. Keep the module-level default in sync, including
  // when the user changes it in Settings, so all displayed amounts re-flow.
  useEffect(() => {
    setAppCurrency(defaultCurrency);
  }, [defaultCurrency]);

  const decimalsFor = useCallback(
    (code: string) =>
      currencies.find((c) => c.code === code)?.decimal_places ?? 2,
    [currencies],
  );

  const updateDefaultCurrency = useCallback(async (code: string) => {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const { error } = await supabase
      .from("user_settings")
      .upsert({ user_id: user.id, default_currency: code }, { onConflict: "user_id" });
    if (error) throw error;
    setDefaultCurrency(code);
  }, []);

  return (
    <CurrencyContext.Provider
      value={{
        currencies,
        defaultCurrency,
        decimalsFor,
        loading,
        updateDefaultCurrency,
      }}
    >
      {children}
    </CurrencyContext.Provider>
  );
}

export function useCurrencies(): CurrencyContextValue {
  const ctx = useContext(CurrencyContext);
  if (!ctx) {
    throw new Error("useCurrencies must be used within a CurrencyProvider");
  }
  return ctx;
}
