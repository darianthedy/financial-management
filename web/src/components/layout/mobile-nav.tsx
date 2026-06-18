import { useState } from "react";
import { NavLink, useLocation } from "react-router-dom";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { MoreHorizontal } from "lucide-react";
import { navItems } from "./nav-config";
import { cn } from "@/lib/utils/cn";

// Bottom nav on small screens shows the primary destinations plus a "More"
// button that opens a bottom sheet with everything else. This keeps the bar to
// 5 thumb-sized targets while still reaching every page.
export function MobileNav() {
  const [moreOpen, setMoreOpen] = useState(false);
  const { pathname } = useLocation();

  const primaryItems = navItems.filter((i) => i.primary);
  const moreItems = navItems.filter((i) => !i.primary);
  const moreActive = moreItems.some((i) => pathname.startsWith(i.to));

  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 flex border-t border-[var(--color-border)] bg-[var(--color-card)] pb-[env(safe-area-inset-bottom)] md:hidden">
      {primaryItems.map(({ to, label, icon: Icon }) => (
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

      <DialogPrimitive.Root open={moreOpen} onOpenChange={setMoreOpen}>
        <DialogPrimitive.Trigger
          className={cn(
            "flex flex-1 flex-col items-center gap-1 py-2 text-xs font-medium",
            moreActive
              ? "text-[var(--color-primary)]"
              : "text-[var(--color-muted-foreground)]",
          )}
        >
          <MoreHorizontal className="h-5 w-5" />
          More
        </DialogPrimitive.Trigger>
        <DialogPrimitive.Portal>
          <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-black/50 data-[state=open]:animate-in data-[state=closed]:animate-out md:hidden" />
          <DialogPrimitive.Content
            className="fixed inset-x-0 bottom-0 z-50 rounded-t-[calc(var(--radius)*2)] border-t border-[var(--color-border)] bg-[var(--color-card)] pb-[env(safe-area-inset-bottom)] shadow-lg data-[state=open]:animate-in data-[state=open]:slide-in-from-bottom md:hidden"
          >
            <DialogPrimitive.Title className="px-5 pb-2 pt-4 text-sm font-semibold text-[var(--color-muted-foreground)]">
              More
            </DialogPrimitive.Title>
            <div className="flex flex-col px-2 pb-2">
              {moreItems.map(({ to, label, icon: Icon }) => (
                <NavLink
                  key={to}
                  to={to}
                  onClick={() => setMoreOpen(false)}
                  className={({ isActive }) =>
                    cn(
                      "flex items-center gap-3 rounded-[var(--radius)] px-3 py-3 text-sm font-medium transition-colors",
                      isActive
                        ? "bg-[var(--color-primary)] text-[var(--color-primary-foreground)]"
                        : "text-[var(--color-foreground)] hover:bg-[var(--color-muted)]",
                    )
                  }
                >
                  <Icon className="h-5 w-5" />
                  {label}
                </NavLink>
              ))}
            </div>
          </DialogPrimitive.Content>
        </DialogPrimitive.Portal>
      </DialogPrimitive.Root>
    </nav>
  );
}
