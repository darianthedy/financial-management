import {
  createContext,
  useContext,
  useCallback,
  useEffect,
  useState,
  type ReactNode,
} from "react";

export type Theme = "light" | "dark" | "system";

const STORAGE_KEY = "theme";

interface ThemeContextValue {
  /** The user's selected preference: an explicit theme or "system". */
  theme: Theme;
  /** The theme actually applied right now, after resolving "system". */
  resolvedTheme: "light" | "dark";
  setTheme: (theme: Theme) => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

function systemPrefersDark(): boolean {
  return (
    typeof window !== "undefined" &&
    window.matchMedia("(prefers-color-scheme: dark)").matches
  );
}

/** Read the stored preference, defaulting to "system" when unset/invalid. */
function readStoredTheme(): Theme {
  if (typeof window === "undefined") return "system";
  const stored = window.localStorage.getItem(STORAGE_KEY);
  return stored === "light" || stored === "dark" || stored === "system"
    ? stored
    : "system";
}

/** Resolve a preference to a concrete theme, consulting the OS for "system". */
function resolveTheme(theme: Theme): "light" | "dark" {
  return theme === "dark" || (theme === "system" && systemPrefersDark())
    ? "dark"
    : "light";
}

/** Toggle <html class="dark"> and color-scheme so native controls match. */
function applyResolvedTheme(resolved: "light" | "dark") {
  const root = document.documentElement;
  root.classList.toggle("dark", resolved === "dark");
  root.style.colorScheme = resolved;
}

/**
 * Shares the user's theme preference across the app. Persists to localStorage
 * (the same source the inline boot script in index.html reads to avoid a flash
 * of the wrong theme) and follows the OS setting live while on "system".
 *
 * Mounted at the root of App, above routing, so it also covers the login page.
 */
export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(readStoredTheme);
  const [resolvedTheme, setResolvedTheme] = useState<"light" | "dark">(() =>
    resolveTheme(readStoredTheme()),
  );

  // Recompute and apply the resolved theme whenever the preference changes, and
  // — while on "system" — whenever the OS preference flips.
  useEffect(() => {
    const resolve = () => {
      const resolved = resolveTheme(theme);
      applyResolvedTheme(resolved);
      setResolvedTheme(resolved);
    };
    resolve();
    if (theme === "system") {
      const media = window.matchMedia("(prefers-color-scheme: dark)");
      media.addEventListener("change", resolve);
      return () => media.removeEventListener("change", resolve);
    }
  }, [theme]);

  const setTheme = useCallback((next: Theme) => {
    window.localStorage.setItem(STORAGE_KEY, next);
    setThemeState(next);
  }, []);

  return (
    <ThemeContext.Provider value={{ theme, resolvedTheme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) {
    throw new Error("useTheme must be used within a ThemeProvider");
  }
  return ctx;
}
