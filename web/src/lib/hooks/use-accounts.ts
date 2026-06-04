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
export async function createAccount(values: AccountFormValues, decimalPlaces = 2) {
  const user_id = await currentUserId();
  const { error } = await supabase.from("accounts").insert({
    user_id,
    name: values.name,
    type: values.type,
    currency: values.currency,
    starting_balance: toMinorUnits(values.starting_balance, decimalPlaces),
  });
  if (error) throw error;
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
      currency: values.currency,
      starting_balance: toMinorUnits(values.starting_balance, decimalPlaces),
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

export async function getAccount(id: string): Promise<AccountWithBalance | null> {
  const [{ data: account }, { data: balance }] = await Promise.all([
    supabase.from("accounts").select("*").eq("id", id).maybeSingle(),
    supabase
      .from("v_account_current_balance")
      .select("*")
      .eq("account_id", id)
      .maybeSingle(),
  ]);
  if (!account) return null;
  return {
    ...account,
    current_balance: balance?.current_balance ?? account.starting_balance,
  };
}
