import { ChevronLeft, ChevronRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

interface Props {
  /** Zero-based current page index. */
  page: number;
  pageSize: number;
  /** Total rows across all pages (the full filtered count). */
  total: number;
  /** Selectable page sizes for the dropdown. */
  pageSizeOptions: number[];
  onPageChange: (page: number) => void;
  onPageSizeChange: (size: number) => void;
}

/**
 * Bottom-right pager: "x–y of N" readout, prev/next with a "page / pages"
 * indicator, then the page-size dropdown. The readout and dropdown always show
 * (when there are any rows); the prev/next group only appears once there's more
 * than one page. Page index and size are owned by the page (kept in the URL), so
 * this is a controlled component.
 */
export function TransactionPagination({
  page,
  pageSize,
  total,
  pageSizeOptions,
  onPageChange,
  onPageSizeChange,
}: Props) {
  if (total === 0) return null;

  const pageCount = Math.ceil(total / pageSize);
  const from = page * pageSize + 1;
  const to = Math.min(total, (page + 1) * pageSize);

  return (
    <div className="flex flex-wrap items-center justify-end gap-2 pt-1">
      <span className="text-xs text-[var(--color-muted-foreground)]">
        {from}–{to} of {total}
      </span>

      {pageCount > 1 && (
        <div className="flex items-center gap-1">
          <Button
            variant="outline"
            size="sm"
            onClick={() => onPageChange(page - 1)}
            disabled={page <= 0}
            aria-label="Previous page"
          >
            <ChevronLeft className="h-4 w-4" />
          </Button>
          <span className="px-1 text-xs text-[var(--color-muted-foreground)]">
            {page + 1} / {pageCount}
          </span>
          <Button
            variant="outline"
            size="sm"
            onClick={() => onPageChange(page + 1)}
            disabled={page >= pageCount - 1}
            aria-label="Next page"
          >
            <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
      )}

      <Select
        value={String(pageSize)}
        onValueChange={(v) => onPageSizeChange(Number(v))}
      >
        <SelectTrigger
          className="h-8 w-auto gap-1 px-2 text-xs"
          aria-label="Items per page"
        >
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {pageSizeOptions.map((n) => (
            <SelectItem key={n} value={String(n)}>
              {n} / page
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
