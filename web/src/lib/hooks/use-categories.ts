import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Category } from "@/lib/types/database";

/** List the current user's categories (alphabetical) with realtime updates. */
export function useCategories() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setCategories([]);
      setLoading(false);
      return;
    }
    const { data } = await supabase
      .from("categories")
      .select("*")
      .eq("user_id", user.id)
      .order("name");
    setCategories(data ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetch();
    const channel = supabase
      .channel("categories-changes")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "categories" },
        () => fetch(),
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetch]);

  return { categories, loading, refetch: fetch };
}

export async function updateCategory(
  id: string,
  values: { name: string; color?: string | null; icon?: string | null },
) {
  const { error } = await supabase
    .from("categories")
    .update({
      name: values.name,
      color: values.color ?? null,
      icon: values.icon ?? null,
    })
    .eq("id", id);
  if (error) throw error;
}

/**
 * Hard-delete a category. The `transactions.category_id` FK is ON DELETE SET
 * NULL, so any transactions using it are simply uncategorized — no orphan rows.
 */
export async function deleteCategory(id: string) {
  const { error } = await supabase.from("categories").delete().eq("id", id);
  if (error) throw error;
}
