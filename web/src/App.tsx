import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { ThemeProvider } from "@/lib/hooks/use-theme";
import { AuthGuard } from "@/components/auth/auth-guard";
import { AppLayout } from "@/components/layout/app-layout";
import LoginPage from "@/pages/login";
import DashboardPage from "@/pages/dashboard";
import AccountsPage from "@/pages/accounts";
import TransactionsPage from "@/pages/transactions";
import TransactionFormPage from "@/pages/transaction-form";
import BudgetsPage from "@/pages/budgets";
import CategoriesPage from "@/pages/categories";
import TagsPage from "@/pages/tags";
import SettingsPage from "@/pages/settings";
import ScheduledPage from "@/pages/scheduled";
import FixedExpensesPage from "@/pages/fixed-expenses";

const basename = import.meta.env.BASE_URL;

export default function App() {
  return (
    <ThemeProvider>
      <BrowserRouter basename={basename}>
        <Routes>
          <Route path="/login" element={<LoginPage />} />

          <Route element={<AuthGuard />}>
            <Route element={<AppLayout />}>
              <Route path="/dashboard" element={<DashboardPage />} />
              <Route path="/accounts" element={<AccountsPage />} />
              <Route path="/transactions" element={<TransactionsPage />} />
              <Route path="/transactions/new" element={<TransactionFormPage />} />
              <Route path="/transactions/:id/edit" element={<TransactionFormPage />} />
              <Route path="/budgets" element={<BudgetsPage />} />
              <Route path="/categories" element={<CategoriesPage />} />
              <Route path="/tags" element={<TagsPage />} />
              <Route path="/fixed-expenses" element={<FixedExpensesPage />} />
              <Route path="/scheduled" element={<ScheduledPage />} />
              <Route path="/settings" element={<SettingsPage />} />
            </Route>
          </Route>

          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </BrowserRouter>
    </ThemeProvider>
  );
}
