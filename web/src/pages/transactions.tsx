import { useCallback, useMemo } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { TransactionList } from "@/components/transactions/transaction-list";
import { TransactionFiltersBar } from "@/components/transactions/transaction-filters";
import type { TransactionFilters } from "@/lib/hooks/use-transactions";
import {
  parseFilters,
  serializeFilters,
} from "@/lib/utils/transaction-filters";

export default function TransactionsPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  // The URL query string is the single source of truth for the active filters.
  const filters = useMemo(
    () => parseFilters(searchParams),
    [searchParams],
  );

  const setFilters = useCallback(
    (next: TransactionFilters) => {
      // replace: filter tweaks shouldn't pile up in browser history.
      setSearchParams(serializeFilters(next), { replace: true });
    },
    [setSearchParams],
  );

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Transactions</h1>
        <Button onClick={() => navigate("/transactions/new")}>
          <Plus className="h-4 w-4" /> Add
        </Button>
      </div>

      <TransactionFiltersBar filters={filters} onChange={setFilters} />

      <TransactionList filters={filters} showAddButton={false} hideHeader />
    </div>
  );
}
