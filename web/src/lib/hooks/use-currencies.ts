import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import { registerCurrencyDecimals } from "@/lib/utils/currency";
import type { Currency } from "@/lib/types/database";

export function useCurrencies() {
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

  const decimalsFor = useCallback(
    (code: string) =>
      currencies.find((c) => c.code === code)?.decimal_places ?? 2,
    [currencies],
  );

  return { currencies, defaultCurrency, decimalsFor, loading };
}
