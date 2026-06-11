import { useCallback, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { BarChart3, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { TransactionList } from "@/components/transactions/transaction-list";
import { TransactionFiltersBar } from "@/components/transactions/transaction-filters";
import { TransactionSummary } from "@/components/transactions/transaction-summary";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import type {
  TransactionFilters,
  TransactionWithRelations,
} from "@/lib/hooks/use-transactions";
import {
  parseFilters,
  serializeFilters,
} from "@/lib/utils/transaction-filters";

export default function TransactionsPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  // Filtered rows lifted from the list so the summary reflects exactly what the
  // current filters return, without a second fetch. `null` until the first load.
  const [loaded, setLoaded] = useState<TransactionWithRelations[] | null>(null);

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
        <div className="flex items-center gap-2">
          {/* Modal dialog; its content only mounts when open, so the summary
              math runs on demand rather than on every page load. */}
          <Dialog>
            <DialogTrigger asChild>
              <Button variant="outline">
                <BarChart3 className="h-4 w-4" /> Summary
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Summary</DialogTitle>
              </DialogHeader>
              {loaded && loaded.length > 0 ? (
                <TransactionSummary transactions={loaded} />
              ) : (
                <p className="text-sm text-[var(--color-muted-foreground)]">
                  No transactions to summarize.
                </p>
              )}
            </DialogContent>
          </Dialog>
          <Button onClick={() => navigate("/transactions/new")}>
            <Plus className="h-4 w-4" /> Add
          </Button>
        </div>
      </div>

      <TransactionFiltersBar filters={filters} onChange={setFilters} />

      <TransactionList
        filters={filters}
        showAddButton={false}
        hideHeader
        onLoaded={setLoaded}
      />
    </div>
  );
}
