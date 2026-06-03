import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useAccounts } from "@/lib/hooks/use-accounts";
import { TransactionList } from "@/components/transactions/transaction-list";
import type { TransactionFilters } from "@/lib/hooks/use-transactions";

export default function TransactionsPage() {
  const navigate = useNavigate();
  const { accounts } = useAccounts();
  const [filters, setFilters] = useState<TransactionFilters>({});

  // Radix SelectItem forbids value=""; use "all" as the sentinel for "no filter".
  function setFilter<K extends keyof TransactionFilters>(
    key: K,
    value: TransactionFilters[K] | "all",
  ) {
    setFilters((prev) => ({
      ...prev,
      [key]: value === "all" ? undefined : value,
    }));
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Transactions</h1>
        <Button onClick={() => navigate("/transactions/new")}>
          <Plus className="h-4 w-4" /> Add
        </Button>
      </div>

      {/* Filter bar */}
      <div className="flex flex-wrap gap-2">
        <Select
          value={filters.type ?? "all"}
          onValueChange={(v) =>
            setFilter("type", v as TransactionFilters["type"] | "all")
          }
        >
          <SelectTrigger className="w-36">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All types</SelectItem>
            <SelectItem value="income">Income</SelectItem>
            <SelectItem value="expense">Expense</SelectItem>
            <SelectItem value="transfer">Transfer</SelectItem>
          </SelectContent>
        </Select>

        <Select
          value={filters.accountId ?? "all"}
          onValueChange={(v) => setFilter("accountId", v === "all" ? "all" : v)}
        >
          <SelectTrigger className="w-44">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All accounts</SelectItem>
            {accounts.map((a) => (
              <SelectItem key={a.id} value={a.id}>
                {a.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Select
          value={filters.status ?? "all"}
          onValueChange={(v) =>
            setFilter("status", v as TransactionFilters["status"] | "all")
          }
        >
          <SelectTrigger className="w-36">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All statuses</SelectItem>
            <SelectItem value="confirmed">Confirmed</SelectItem>
            <SelectItem value="pending">Pending</SelectItem>
            <SelectItem value="dismissed">Dismissed</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <TransactionList
        filters={filters}
        showAddButton={false}
      />
    </div>
  );
}
