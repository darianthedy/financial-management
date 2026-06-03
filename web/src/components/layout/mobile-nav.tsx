import { NavLink } from "react-router-dom";
import { navItems } from "./nav-config";
import { cn } from "@/lib/utils/cn";

// Bottom nav on small screens shows only the primary (implemented) destinations.
export function MobileNav() {
  const items = navItems.filter((i) => i.primary);
  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 flex border-t border-[var(--color-border)] bg-[var(--color-card)] md:hidden">
      {items.map(({ to, label, icon: Icon }) => (
        <NavLink
          key={to}
          to={to}
          className={({ isActive }) =>
            cn(
              "flex flex-1 flex-col items-center gap-1 py-2 text-xs font-medium",
              isActive
                ? "text-[var(--color-primary)]"
                : "text-[var(--color-muted-foreground)]",
            )
          }
        >
          <Icon className="h-5 w-5" />
          {label}
        </NavLink>
      ))}
    </nav>
  );
}
