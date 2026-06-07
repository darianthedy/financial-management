import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Tag } from "@/lib/types/database";

/** List the current user's tags (alphabetical) with realtime updates. */
export function useTags() {
  const [tags, setTags] = useState<Tag[]>([]);
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setTags([]);
      setLoading(false);
      return;
    }
    const { data } = await supabase
      .from("tags")
      .select("*")
      .eq("user_id", user.id)
      .order("name");
    setTags(data ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetch();
    const channel = supabase
      .channel("tags-changes")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "tags" },
        () => fetch(),
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetch]);

  return { tags, loading, refetch: fetch };
}

export async function updateTag(id: string, name: string) {
  const { error } = await supabase.from("tags").update({ name }).eq("id", id);
  if (error) throw error;
}

/**
 * Hard-delete a tag. The `transaction_tags.tag_id` FK is ON DELETE CASCADE, so
 * its junction rows are removed and tagged transactions simply lose this tag.
 */
export async function deleteTag(id: string) {
  const { error } = await supabase.from("tags").delete().eq("id", id);
  if (error) throw error;
}
