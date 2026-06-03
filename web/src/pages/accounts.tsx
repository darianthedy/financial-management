import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Plus } from "lucide-react";
import { useAccounts, archiveAccount } from "@/lib/hooks/use-accounts";
import { AccountCard } from "@/components/accounts/account-card";
import { AccountForm } from "@/components/accounts/account-form";
import { Button } from "@/components/ui/button";
import { CenteredSpinner, EmptyState } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
import type { Account } from "@/lib/types/database";

export default function AccountsPage() {
  const navigate = useNavigate();
  const { accounts, loading, refetch } = useAccounts();
  const [formOpen, setFormOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<Account | null>(null);

  function openCreate() {
    setEditTarget(null);
    setFormOpen(true);
  }

  function openEdit(account: Account) {
    setEditTarget(account);
    setFormOpen(true);
  }

  async function handleArchive(id: string) {
    if (!confirm("Archive this account? It will no longer appear in lists."))
      return;
    await archiveAccount(id);
    refetch();
  }

  // Net worth: sum all balances (may mix currencies — display as-is for now)
  const totalsByCurrency = accounts.reduce<Record<string, number>>((acc, a) => {
    acc[a.currency] = (acc[a.currency] ?? 0) + a.current_balance;
    return acc;
  }, {});

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Accounts</h1>
          {Object.entries(totalsByCurrency).map(([currency, total]) => (
            <p
              key={currency}
              className="text-sm text-[var(--color-muted-foreground)]"
            >
              Total: {formatCurrency(total, currency)}
            </p>
          ))}
        </div>
        <Button onClick={openCreate}>
          <Plus className="h-4 w-4" />
          Add account
        </Button>
      </div>

      {loading ? (
        <CenteredSpinner />
      ) : accounts.length === 0 ? (
        <EmptyState
          title="No accounts yet"
          description="Add your first account to start tracking your finances."
          action={<Button onClick={openCreate}>Add account</Button>}
        />
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          {accounts.map((account) => (
            <AccountCard
              key={account.id}
              account={account}
              onClick={() => navigate(`/accounts/${account.id}`)}
              onEdit={() => openEdit(account)}
              onArchive={() => handleArchive(account.id)}
            />
          ))}
        </div>
      )}

      <AccountForm
        open={formOpen}
        onOpenChange={setFormOpen}
        account={editTarget}
        onSaved={refetch}
      />
    </div>
  );
}
