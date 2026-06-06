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

  // Net worth: sum all balances (single app-wide currency).
  const totalBalance = accounts.reduce((sum, a) => sum + a.current_balance, 0);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Accounts</h1>
          {accounts.length > 0 && (
            <p className="text-sm text-[var(--color-muted-foreground)]">
              Total: {formatCurrency(totalBalance)}
            </p>
          )}
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
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
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
