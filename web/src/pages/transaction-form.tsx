import { useEffect, useState } from "react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import { ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { TransactionForm } from "@/components/transactions/transaction-form";
import { supabase } from "@/lib/supabase/client";
import { CenteredSpinner } from "@/components/ui/misc";
import type { TransactionWithRelations } from "@/lib/hooks/use-transactions";

export default function TransactionFormPage() {
  const navigate = useNavigate();
  const { id } = useParams<{ id?: string }>();
  const [searchParams] = useSearchParams();
  const defaultAccountId = searchParams.get("accountId") ?? undefined;

  const [transaction, setTransaction] = useState<TransactionWithRelations | null>(null);
  const [loading, setLoading] = useState(!!id);

  useEffect(() => {
    if (!id) return;
    setLoading(true);
    (async () => {
      const { data: txnData } = await supabase
        .from("transactions")
        .select("*")
        .eq("id", id)
        .maybeSingle();
      if (!txnData) { setLoading(false); return; }

      const [{ data: categoryRow }, { data: tagLinks }, { data: accountRows }, { data: budgetRow }] = await Promise.all([
        txnData.category_id
          ? supabase.from("categories").select("*").eq("id", txnData.category_id).maybeSingle()
          : Promise.resolve({ data: null as import("@/lib/types/database").Category | null }),
        supabase.from("transaction_tags").select("transaction_id, tags(*)").eq("transaction_id", txnData.id) as unknown as Promise<{ data: Array<{ transaction_id: string; tags: import("@/lib/types/database").Tag | null }> | null }>,
        supabase.from("accounts").select("id, name, image_url").in("id", [txnData.account_id, txnData.transfer_account_id].filter(Boolean) as string[]),
        txnData.budget_id
          ? supabase.from("budgets").select("name").eq("id", txnData.budget_id).maybeSingle()
          : Promise.resolve({ data: null as { name: string } | null }),
      ]);

      const accountById = new Map((accountRows ?? []).map((a) => [a.id, a]));
      setTransaction({
        ...txnData,
        accounts: {
          name: accountById.get(txnData.account_id)?.name ?? "",
          image_url: accountById.get(txnData.account_id)?.image_url ?? null,
        },
        transfer_accounts: txnData.transfer_account_id ? { name: accountById.get(txnData.transfer_account_id)?.name ?? "" } : null,
        category: categoryRow ?? null,
        tags: (tagLinks ?? []).map((t) => t.tags).filter(Boolean) as import("@/lib/types/database").Tag[],
        budget: budgetRow ? { name: budgetRow.name } : null,
      });
      setLoading(false);
    })();
  }, [id]);

  function handleSaved() {
    navigate(-1);
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Button variant="ghost" size="icon" onClick={() => navigate(-1)}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <h1 className="text-2xl font-semibold">
          {id ? "Edit transaction" : "New transaction"}
        </h1>
      </div>

      <Card>
        <CardContent className="pt-5">
          {loading ? (
            <CenteredSpinner />
          ) : (
            <TransactionForm
              transaction={transaction}
              defaultAccountId={defaultAccountId}
              onSaved={handleSaved}
              onCancel={() => navigate(-1)}
            />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
