import { useEffect, useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { ArrowLeft, Pencil, Archive } from "lucide-react";
import {
  getAccount,
  archiveAccount,
  type AccountWithBalance,
} from "@/lib/hooks/use-accounts";
import { AccountForm } from "@/components/accounts/account-form";
import { AccountAvatar } from "@/components/accounts/account-avatar";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/misc";
import { CenteredSpinner } from "@/components/ui/misc";
import { accountTypeLabel } from "@/lib/account-types";
import { formatCurrency } from "@/lib/utils/currency";
import { TransactionList } from "@/components/transactions/transaction-list";

export default function AccountDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [account, setAccount] = useState<AccountWithBalance | null>(null);
  const [loading, setLoading] = useState(true);
  const [formOpen, setFormOpen] = useState(false);

  async function load() {
    if (!id) return;
    setLoading(true);
    const data = await getAccount(id);
    setAccount(data);
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, [id]);

  async function handleArchive() {
    if (!id) return;
    if (!confirm("Archive this account?")) return;
    await archiveAccount(id);
    navigate("/accounts", { replace: true });
  }

  if (loading) return <CenteredSpinner />;
  if (!account)
    return (
      <p className="text-[var(--color-muted-foreground)]">Account not found.</p>
    );

  return (
    <div className="space-y-6">
      <div className="space-y-3 sm:space-y-0">
        <div className="flex items-start gap-2">
          <Link to="/accounts" className="shrink-0">
            <Button variant="ghost" size="icon">
              <ArrowLeft className="h-4 w-4" />
            </Button>
          </Link>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <AccountAvatar
                type={account.type}
                imageUrl={account.image_url}
                name={account.name}
                className="h-8 w-8"
                iconClassName="h-4 w-4"
              />
              <h1 className="truncate text-2xl font-semibold">{account.name}</h1>
              <Badge className="shrink-0">{accountTypeLabel(account.type)}</Badge>
            </div>
            <p className="text-sm text-[var(--color-muted-foreground)]">
              Starting balance: {formatCurrency(account.starting_balance)}
            </p>
          </div>
          {/* Balance + actions sit inline on desktop; they drop to their own row on mobile. */}
          <div className="hidden shrink-0 items-center gap-2 sm:flex">
            <p className="text-xl font-bold">
              {formatCurrency(account.current_balance)}
            </p>
            <Button variant="outline" size="icon" onClick={() => setFormOpen(true)}>
              <Pencil className="h-4 w-4" />
            </Button>
            <Button variant="outline" size="icon" onClick={handleArchive}>
              <Archive className="h-4 w-4" />
            </Button>
          </div>
        </div>
        <div className="flex items-center justify-between gap-2 sm:hidden">
          <p className="min-w-0 truncate text-xl font-bold">
            {formatCurrency(account.current_balance)}
          </p>
          <div className="flex shrink-0 items-center gap-2">
            <Button variant="outline" size="icon" onClick={() => setFormOpen(true)}>
              <Pencil className="h-4 w-4" />
            </Button>
            <Button variant="outline" size="icon" onClick={handleArchive}>
              <Archive className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </div>

      <TransactionList accountId={id} onMutated={load} />

      <AccountForm
        open={formOpen}
        onOpenChange={setFormOpen}
        account={account}
        onSaved={load}
      />
    </div>
  );
}
