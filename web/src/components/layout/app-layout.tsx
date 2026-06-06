import { Outlet } from "react-router-dom";
import { Sidebar } from "./sidebar";
import { Header } from "./header";
import { MobileNav } from "./mobile-nav";
import { CenteredSpinner } from "@/components/ui/misc";
import { CurrencyProvider, useCurrencies } from "@/lib/hooks/use-currencies";

export function AppLayout() {
  // CurrencyProvider loads the currencies + the user's app-wide currency once and
  // shares them with every page, so changing the currency in Settings propagates
  // instantly. It stays mounted across route changes, gating only initial load.
  return (
    <CurrencyProvider>
      <div className="flex h-full">
        <Sidebar />
        <div className="flex min-w-0 flex-1 flex-col">
          <Header />
          <main className="flex-1 overflow-y-auto p-4 pb-20 md:p-6 md:pb-6">
            <div className="mx-auto w-full max-w-5xl">
              <LayoutContent />
            </div>
          </main>
        </div>
        <MobileNav />
      </div>
    </CurrencyProvider>
  );
}

// Gates page render until the currency-decimals registry is populated, so no
// amount renders before its decimal places are known.
function LayoutContent() {
  const { loading } = useCurrencies();
  return loading ? <CenteredSpinner /> : <Outlet />;
}
