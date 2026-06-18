import { LogOut, Moon, Sun } from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { supabase } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { useTheme } from "@/lib/hooks/use-theme";

export function Header() {
  const navigate = useNavigate();
  const { resolvedTheme, setTheme } = useTheme();

  async function handleSignOut() {
    await supabase.auth.signOut();
    navigate("/login", { replace: true });
  }

  // Flip to the opposite of what's currently showing, choosing an explicit
  // light/dark preference (the Settings page exposes the "system" option).
  const isDark = resolvedTheme === "dark";

  return (
    <header className="flex h-14 shrink-0 items-center justify-between border-b border-[var(--color-border)] bg-[var(--color-card)] px-4">
      <Link to="/dashboard" className="text-sm font-medium text-[var(--color-muted-foreground)] hover:text-[var(--color-foreground)] md:hidden">
        Financial Management
      </Link>
      <div className="ml-auto flex items-center gap-1">
        <Button
          variant="ghost"
          size="icon"
          aria-label={isDark ? "Switch to light mode" : "Switch to dark mode"}
          title={isDark ? "Switch to light mode" : "Switch to dark mode"}
          onClick={() => setTheme(isDark ? "light" : "dark")}
        >
          {isDark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
        </Button>
        <Button variant="ghost" size="sm" onClick={handleSignOut}>
          <LogOut className="h-4 w-4" />
          Sign out
        </Button>
      </div>
    </header>
  );
}
