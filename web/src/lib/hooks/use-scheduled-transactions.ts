import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase/client";
import type { ScheduledTransaction } from "@/lib/types/database";
import type { ScheduledTransactionFormValues } from "@/lib/validations/scheduled-transaction";
import { toMinorUnits } from "@/lib/utils/currency";

export type ScheduledTransactionWithAccount = ScheduledTransaction & {
  accounts: { name: string; image_url: string | null } | null;
  category: { name: string; color: string | null } | null;
  tags: { id: string; name: string }[];
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
    const ids = list.map((r) => r.id);
    const accountIds = [...new Set(list.map((r) => r.account_id))];
    const catIds = [
      ...new Set(list.map((r) => r.category_id).filter(Boolean)),
    ] as string[];

    // Account names, categories, and tag links resolved via separate lookups
    // (the type shim carries no Relationships, so no FK-hint embeds).
    const [accountResult, categoryResult, tagResult] = await Promise.all([
      accountIds.length
        ? supabase.from("accounts").select("id, name, image_url").in("id", accountIds)
        : Promise.resolve({
            data: [] as Array<{ id: string; name: string; image_url: string | null }>,
          }),
      catIds.length
        ? supabase.from("categories").select("id, name, color").in("id", catIds)
        : Promise.resolve({
            data: [] as Array<{ id: string; name: string; color: string | null }>,
          }),
      ids.length
        ? (supabase
            .from("scheduled_transaction_tags")
            .select("scheduled_transaction_id, tags(id, name)")
            .in("scheduled_transaction_id", ids) as unknown as Promise<{
            data: Array<{
              scheduled_transaction_id: string;
              tags: { id: string; name: string } | null;
            }> | null;
          }>)
        : Promise.resolve({
            data: [] as Array<{
              scheduled_transaction_id: string;
              tags: { id: string; name: string } | null;
            }>,
          }),
    ]);

    const accountById = new Map((accountResult.data ?? []).map((a) => [a.id, a]));
    const categoryById = new Map(
      (categoryResult.data ?? []).map((c) => [c.id, c]),
    );
    const tagsBySched = new Map<string, { id: string; name: string }[]>();
    for (const link of tagResult.data ?? []) {
      const tags = tagsBySched.get(link.scheduled_transaction_id) ?? [];
      if (link.tags) tags.push(link.tags);
      tagsBySched.set(link.scheduled_transaction_id, tags);
    }

    setScheduled(
      list.map((r) => ({
        ...r,
        accounts: r.account_id
          ? {
              name: accountById.get(r.account_id)?.name ?? "",
              image_url: accountById.get(r.account_id)?.image_url ?? null,
            }
          : null,
        category: r.category_id
          ? {
              name: categoryById.get(r.category_id)?.name ?? "",
              color: categoryById.get(r.category_id)?.color ?? null,
            }
          : null,
        tags: tagsBySched.get(r.id) ?? [],
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

async function writeTagRows(scheduledId: string, tagIds: string[]) {
  if (!tagIds.length) return;
  const { error } = await supabase
    .from("scheduled_transaction_tags")
    .insert(
      tagIds.map((id) => ({
        scheduled_transaction_id: scheduledId,
        tag_id: id,
      })),
    );
  if (error) throw error;
}

export async function createScheduledTransaction(
  values: ScheduledTransactionFormValues,
  decimalPlaces = 2,
) {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { data, error } = await supabase
    .from("scheduled_transactions")
    .insert({
      user_id: user.id,
      account_id: values.account_id,
      type: values.type,
      amount: toMinorUnits(values.amount, decimalPlaces),
      description: values.description?.trim() ? values.description.trim() : null,
      recurrence: values.recurrence,
      next_due_date: values.next_due_date,
      is_active: values.is_active,
      category_id: values.category_id ?? null,
      budget_name: values.budget_name ?? null,
    })
    .select("id")
    .single();
  if (error) throw error;
  await writeTagRows(data.id, values.tag_ids ?? []);
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
      category_id: values.category_id ?? null,
      budget_name: values.budget_name ?? null,
    })
    .eq("id", id);
  if (error) throw error;
  await supabase
    .from("scheduled_transaction_tags")
    .delete()
    .eq("scheduled_transaction_id", id);
  await writeTagRows(id, values.tag_ids ?? []);
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
