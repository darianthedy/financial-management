import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Account } from "@/lib/types/database";
import type { AccountFormValues } from "@/lib/validations/account";
import { toMinorUnits } from "@/lib/utils/currency";

export type AccountWithBalance = Account & { current_balance: number };

export function useAccounts() {
  const [accounts, setAccounts] = useState<AccountWithBalance[]>([]);
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    const [{ data: accountRows }, { data: balanceRows }] = await Promise.all([
      supabase
        .from("accounts")
        .select("*")
        .eq("is_archived", false)
        .order("created_at", { ascending: true }),
      supabase.from("v_account_current_balance").select("*"),
    ]);

    const balanceByAccount = new Map(
      (balanceRows ?? []).map((b) => [b.account_id, b.current_balance]),
    );

    setAccounts(
      (accountRows ?? []).map((a) => ({
        ...a,
        current_balance: balanceByAccount.get(a.id) ?? a.starting_balance,
      })),
    );
    setLoading(false);
  }, []);

  useEffect(() => {
    fetch();

    const channel = supabase
      .channel("accounts-changes")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "accounts" },
        () => fetch(),
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "account_monthly_balances" },
        () => fetch(),
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetch]);

  return { accounts, loading, refetch: fetch };
}

async function currentUserId(): Promise<string> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  return user.id;
}

/** Account mutations. Balances are maintained by DB triggers — never written here. */
export async function createAccount(
  values: AccountFormValues,
  decimalPlaces = 2,
): Promise<string> {
  const user_id = await currentUserId();
  const { data, error } = await supabase
    .from("accounts")
    .insert({
      user_id,
      name: values.name,
      type: values.type,
      starting_balance: toMinorUnits(values.starting_balance, decimalPlaces),
      image_url: values.image_url ?? null,
      show_on_dashboard: values.show_on_dashboard,
    })
    .select("id")
    .single();
  if (error) throw error;
  return data.id;
}

export async function updateAccount(
  id: string,
  values: AccountFormValues,
  decimalPlaces = 2,
) {
  const { error } = await supabase
    .from("accounts")
    .update({
      name: values.name,
      type: values.type,
      starting_balance: toMinorUnits(values.starting_balance, decimalPlaces),
      image_url: values.image_url ?? null,
      show_on_dashboard: values.show_on_dashboard,
    })
    .eq("id", id);
  if (error) throw error;
}

export async function archiveAccount(id: string) {
  const { error } = await supabase
    .from("accounts")
    .update({ is_archived: true })
    .eq("id", id);
  if (error) throw error;
}

/**
 * The user's preferred default account for new transactions, or null. Stored on
 * user_settings alongside default_currency (the app's preference store).
 */
export async function fetchDefaultAccountId(): Promise<string | null> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const { data } = await supabase
    .from("user_settings")
    .select("default_account_id")
    .eq("user_id", user.id)
    .maybeSingle();
  return data?.default_account_id ?? null;
}

/** Persist the preferred default account; pass null to clear it. */
export async function updateDefaultAccountId(
  accountId: string | null,
): Promise<void> {
  const user_id = await currentUserId();
  const { error } = await supabase
    .from("user_settings")
    .upsert(
      { user_id, default_account_id: accountId },
      { onConflict: "user_id" },
    );
  if (error) throw error;
}
