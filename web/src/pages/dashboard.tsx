import { useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CenteredSpinner } from "@/components/ui/misc";
import { CashflowCard } from "@/components/dashboard/cashflow-card";
import { SpendingByCategoryCard } from "@/components/dashboard/spending-by-category";
import { BudgetProgressCard } from "@/components/dashboard/budget-progress";
import { RecentTransactionsCard } from "@/components/dashboard/recent-transactions";
import { useDashboard } from "@/lib/hooks/use-dashboard";
import { getCurrentYearMonth, navigateMonth, formatYearMonth } from "@/lib/utils/date";

export default function DashboardPage() {
  const [yearMonth, setYearMonth] = useState(getCurrentYearMonth());
  const { cashflow, spendingByCategory, budgetProgress, recentTransactions, loading } =
    useDashboard(yearMonth);

  return (
    <div className="space-y-6">
      {/* Month navigator */}
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Dashboard</h1>
        <div className="flex items-center gap-2">
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
      </div>

      {loading ? (
        <CenteredSpinner />
      ) : (
        <div className="grid gap-4 md:grid-cols-2">
          <CashflowCard cashflow={cashflow} />
          <SpendingByCategoryCard data={spendingByCategory} />
          <div className="md:col-span-2">
            <BudgetProgressCard budgets={budgetProgress} />
          </div>
          <div className="md:col-span-2">
            <RecentTransactionsCard transactions={recentTransactions} />
          </div>
        </div>
      )}
    </div>
  );
}
