import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase/client";
import type { ScheduledTransaction } from "@/lib/types/database";
import type { ScheduledTransactionFormValues } from "@/lib/validations/scheduled-transaction";
import { toMinorUnits } from "@/lib/utils/currency";

export type ScheduledTransactionWithAccount = ScheduledTransaction & {
  accounts: { name: string; image_url: string | null } | null;
};

/**
 * List the current user's scheduled transactions (soonest due first) with the
 * linked account name resolved via a separate lookup (plain select("*"), no
 * FK-hint — the type shim has no Relationships). Realtime on the table.
 */
export function useScheduledTransactions() {
  const [scheduled, setScheduled] = useState<ScheduledTransactionWithAccount[]>(
    [],
  );
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setScheduled([]);
      setLoading(false);
      return;
    }

    const { data: rows } = await supabase
      .from("scheduled_transactions")
      .select("*")
      .eq("user_id", user.id)
      .order("is_active", { ascending: false })
      .order("next_due_date", { ascending: true });

    const list = rows ?? [];
    const accountIds = [...new Set(list.map((r) => r.account_id))];

    const { data: accountRows } = accountIds.length
      ? await supabase
          .from("accounts")
          .select("id, name, image_url")
          .in("id", accountIds)
      : { data: [] as Array<{ id: string; name: string; image_url: string | null }> };

    const accountById = new Map((accountRows ?? []).map((a) => [a.id, a]));

    setScheduled(
      list.map((r) => ({
        ...r,
        accounts: r.account_id
          ? {
              name: accountById.get(r.account_id)?.name ?? "",
              image_url: accountById.get(r.account_id)?.image_url ?? null,
            }
          : null,
      })),
    );
    setLoading(false);
  }, []);

  useEffect(() => {
    fetch();
    const channel = supabase
      .channel("scheduled-transactions-changes")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "scheduled_transactions" },
        () => fetch(),
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetch]);

  return { scheduled, loading, refetch: fetch };
}

export async function createScheduledTransaction(
  values: ScheduledTransactionFormValues,
  decimalPlaces = 2,
) {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { error } = await supabase.from("scheduled_transactions").insert({
    user_id: user.id,
    account_id: values.account_id,
    type: values.type,
    amount: toMinorUnits(values.amount, decimalPlaces),
    description: values.description?.trim() ? values.description.trim() : null,
    recurrence: values.recurrence,
    next_due_date: values.next_due_date,
    is_active: values.is_active,
  });
  if (error) throw error;
}

export async function updateScheduledTransaction(
  id: string,
  values: ScheduledTransactionFormValues,
  decimalPlaces = 2,
) {
  const { error } = await supabase
    .from("scheduled_transactions")
    .update({
      account_id: values.account_id,
      type: values.type,
      amount: toMinorUnits(values.amount, decimalPlaces),
      description: values.description?.trim() ? values.description.trim() : null,
      recurrence: values.recurrence,
      next_due_date: values.next_due_date,
      is_active: values.is_active,
    })
    .eq("id", id);
  if (error) throw error;
}

/** Pause/resume a schedule without editing it. */
export async function setScheduledActive(id: string, isActive: boolean) {
  const { error } = await supabase
    .from("scheduled_transactions")
    .update({ is_active: isActive })
    .eq("id", id);
  if (error) throw error;
}

export async function deleteScheduledTransaction(id: string) {
  const { error } = await supabase
    .from("scheduled_transactions")
    .delete()
    .eq("id", id);
  if (error) throw error;
}
