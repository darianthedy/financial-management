import { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { BarChart3, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { TransactionList } from "@/components/transactions/transaction-list";
import { TransactionFiltersBar } from "@/components/transactions/transaction-filters";
import { TransactionSummary } from "@/components/transactions/transaction-summary";
import { TransactionPagination } from "@/components/transactions/transaction-pagination";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  useTransactions,
  fetchTransactionSummaryRows,
  type TransactionFilters,
  type TransactionSummaryRow,
} from "@/lib/hooks/use-transactions";
import {
  parseFilters,
  serializeFilters,
} from "@/lib/utils/transaction-filters";

const PAGE_SIZE_OPTIONS = [25, 50, 100, 200];
const DEFAULT_PAGE_SIZE = 25;

export default function TransactionsPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  // The URL query string is the single source of truth for filters, the current
  // page, and the page size. Filters live in the named params; `page` (1-based
  // in the URL, 0-based internally) and `size` are separate, kept out of
  // serializeFilters so changing a filter resets the page but keeps the size.
  const filters = useMemo(() => parseFilters(searchParams), [searchParams]);
  const page = Math.max(0, (Number(searchParams.get("page")) || 1) - 1);
  const rawSize = Number(searchParams.get("size"));
  const pageSize = PAGE_SIZE_OPTIONS.includes(rawSize)
    ? rawSize
    : DEFAULT_PAGE_SIZE;

  const { transactions, total, loading, refetch } = useTransactions(filters, {
    page,
    pageSize,
  });

  // Build the URL params from filters plus the non-filter page/size state,
  // keeping page 1 and the default size implicit for clean URLs.
  const buildSearch = useCallback(
    (
      nextFilters: TransactionFilters,
      opts: { page: number; size: number },
    ) => {
      const params = serializeFilters(nextFilters);
      if (opts.size !== DEFAULT_PAGE_SIZE) params.size = String(opts.size);
      if (opts.page > 0) params.page = String(opts.page + 1);
      return params;
    },
    [],
  );

  const setFilters = useCallback(
    (next: TransactionFilters) => {
      // replace: filter tweaks shouldn't pile up in browser history. Page resets
      // to the first page; the page size is a view preference, so it's kept.
      setSearchParams(buildSearch(next, { page: 0, size: pageSize }), {
        replace: true,
      });
    },
    [buildSearch, pageSize, setSearchParams],
  );

  const setPage = useCallback(
    (next: number) => {
      // push (not replace) so the back button steps through visited pages.
      setSearchParams(buildSearch(filters, { page: next, size: pageSize }));
    },
    [buildSearch, filters, pageSize, setSearchParams],
  );

  const setPageSize = useCallback(
    (next: number) => {
      // Changing the size resets to the first page so we never land past the end.
      setSearchParams(buildSearch(filters, { page: 0, size: next }), {
        replace: true,
      });
    },
    [buildSearch, filters, setSearchParams],
  );

  // If rows are deleted (or filters narrow) so the current page no longer
  // exists, fall back to the last valid page.
  const pageCount = Math.ceil(total / pageSize);
  useEffect(() => {
    if (!loading && pageCount > 0 && page >= pageCount) {
      setPage(pageCount - 1);
    }
  }, [loading, pageCount, page, setPage]);

  // Summary dialog: the totals must span the whole filtered set, not just the
  // visible page, so fetch it separately — and only on demand, when the dialog
  // is open (refetching if the filters change while it's open).
  const [summaryOpen, setSummaryOpen] = useState(false);
  const [summaryRows, setSummaryRows] = useState<TransactionSummaryRow[] | null>(
    null,
  );
  const filterKey = JSON.stringify(serializeFilters(filters));
  useEffect(() => {
    if (!summaryOpen) return;
    let active = true;
    (async () => {
      const rows = await fetchTransactionSummaryRows(filters);
      if (active) setSummaryRows(rows);
    })();
    return () => {
      active = false;
    };
    // filterKey stands in for filters (stable identity).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [summaryOpen, filterKey]);

  // Reset to the loading state when opening (in the event handler, not the
  // effect) so the dialog shows "Loading…" until the fresh whole-set fetch lands.
  const handleSummaryOpenChange = useCallback((open: boolean) => {
    if (open) setSummaryRows(null);
    setSummaryOpen(open);
  }, []);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Transactions</h1>
        <div className="flex items-center gap-2">
          <Dialog open={summaryOpen} onOpenChange={handleSummaryOpenChange}>
            <DialogTrigger asChild>
              <Button variant="outline">
                <BarChart3 className="h-4 w-4" /> Summary
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Summary</DialogTitle>
              </DialogHeader>
              {summaryRows === null ? (
                <p className="text-sm text-[var(--color-muted-foreground)]">
                  Loading…
                </p>
              ) : summaryRows.length > 0 ? (
                <TransactionSummary transactions={summaryRows} />
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
        transactions={transactions}
        loading={loading}
        showAddButton={false}
        hideHeader
        onMutated={refetch}
      />

      <TransactionPagination
        page={page}
        pageSize={pageSize}
        total={total}
        pageSizeOptions={PAGE_SIZE_OPTIONS}
        onPageChange={setPage}
        onPageSizeChange={setPageSize}
      />
    </div>
  );
}
