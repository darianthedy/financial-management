import { Outlet } from "react-router-dom";
import { Sidebar } from "./sidebar";
import { Header } from "./header";
import { MobileNav } from "./mobile-nav";
import { CenteredSpinner } from "@/components/ui/misc";
import { useCurrencies } from "@/lib/hooks/use-currencies";

export function AppLayout() {
  // Load currencies once here so the currency-decimals registry is populated
  // before any page renders an amount. The layout stays mounted across route
  // changes, so this gates only the initial app load.
  const { loading } = useCurrencies();

  return (
    <div className="flex h-full">
      <Sidebar />
      <div className="flex min-w-0 flex-1 flex-col">
        <Header />
        <main className="flex-1 overflow-y-auto p-4 pb-20 md:p-6 md:pb-6">
          <div className="mx-auto w-full max-w-5xl">
            {loading ? <CenteredSpinner /> : <Outlet />}
          </div>
        </main>
      </div>
      <MobileNav />
    </div>
  );
}
