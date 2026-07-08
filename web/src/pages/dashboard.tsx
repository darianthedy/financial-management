import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { ChevronLeft, ChevronRight, Receipt } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CenteredSpinner } from "@/components/ui/misc";
import { VerdictBanner } from "@/components/dashboard/verdict-banner";
import { AccountsCard } from "@/components/dashboard/accounts-card";
import { PlannedExpensesCard } from "@/components/dashboard/planned-expenses";
import { UnplannedExpensesCard } from "@/components/dashboard/unplanned-expenses";
import { useDashboard } from "@/lib/hooks/use-dashboard";
import {
  getCurrentYearMonth,
  navigateMonth,
  formatYearMonth,
  monthDateBounds,
} from "@/lib/utils/date";

export default function DashboardPage() {
  const navigate = useNavigate();
  const [yearMonth, setYearMonth] = useState(getCurrentYearMonth());

  // Open the Transactions page scoped to the month currently shown here. The
  // list reads `from`/`to` straight from the query string (see parseFilters).
  const openTransactions = () => {
    const { from, to } = monthDateBounds(yearMonth);
    navigate(`/transactions?${new URLSearchParams({ from, to }).toString()}`);
  };
  const {
    unplannedExpenses,
    fixedExpenses,
    budgetProgress,
    accounts,
    loading,
  } = useDashboard(yearMonth);

  return (
    <div className="space-y-6">
      {/* Month navigator */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <h1 className="text-2xl font-semibold">Dashboard</h1>
        <div className="flex flex-col items-stretch gap-2 sm:flex-row sm:items-center sm:justify-end">
          <div className="flex items-center justify-center gap-2">
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setYearMonth((ym) => navigateMonth(ym, -1))}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <span className="min-w-32 text-center text-sm font-medium">
              {formatYearMonth(yearMonth)}
            </span>
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setYearMonth((ym) => navigateMonth(ym, 1))}
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
          <Button
            variant="outline"
            size="sm"
            className="w-full sm:w-auto"
            onClick={openTransactions}
          >
            <Receipt className="h-4 w-4" /> Transactions
          </Button>
        </div>
      </div>

      {loading ? (
        <CenteredSpinner />
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div className="md:col-span-2">
            <VerdictBanner budgets={budgetProgress} fixedExpenses={fixedExpenses} />
          </div>
          <div className="md:col-span-2">
            <AccountsCard accounts={accounts} />
          </div>
          <PlannedExpensesCard
            budgets={budgetProgress}
            fixedExpenses={fixedExpenses}
            yearMonth={yearMonth}
          />
          <UnplannedExpensesCard spending={unplannedExpenses} />
        </div>
      )}
    </div>
  );
}
