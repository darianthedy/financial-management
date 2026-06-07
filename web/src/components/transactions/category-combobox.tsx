import { useEffect, useMemo, useRef, useState } from "react";
import { Check, Plus, X } from "lucide-react";
import { Input } from "@/components/ui/input";
import type { Category } from "@/lib/types/database";

interface Props {
  categories: Category[];
  /** The selected category id, or null when none is chosen. */
  value: string | null;
  onChange: (id: string | null) => void;
  /** Persists a brand-new category and returns the created row. */
  onCreate: (name: string) => Promise<Category>;
}

/**
 * Autocomplete + create combobox for a single category. Typing filters existing
 * categories; selecting one sets it as the (single) value, shown as a chip. If
 * the typed name has no exact match, an inline "Create" option persists a new
 * category on the fly. A transaction has at most one category, so selecting a
 * new one replaces the current selection.
 */
export function CategoryCombobox({ categories, value, onChange, onCreate }: Props) {
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const [highlight, setHighlight] = useState(0);
  const [creating, setCreating] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  const byId = useMemo(
    () => new Map(categories.map((c) => [c.id, c])),
    [categories],
  );
  const selected = value ? byId.get(value) ?? null : null;

  const trimmed = query.trim();
  const matches = useMemo(() => {
    const q = trimmed.toLowerCase();
    return categories.filter(
      (c) => c.id !== value && (!q || c.name.toLowerCase().includes(q)),
    );
  }, [categories, value, trimmed]);

  const exactMatch = categories.some(
    (c) => c.name.toLowerCase() === trimmed.toLowerCase(),
  );
  const showCreate = trimmed.length > 0 && !exactMatch;

  // Total selectable options = filtered matches + optional create row.
  const optionCount = matches.length + (showCreate ? 1 : 0);

  useEffect(() => {
    setHighlight(0);
  }, [trimmed, open]);

  // Close the dropdown when clicking outside the component.
  useEffect(() => {
    if (!open) return;
    function onClick(e: MouseEvent) {
      if (!containerRef.current?.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", onClick);
    return () => document.removeEventListener("mousedown", onClick);
  }, [open]);

  function selectCategory(id: string) {
    onChange(id);
    setQuery("");
    setOpen(false);
  }

  function clearCategory() {
    onChange(null);
  }

  async function createAndSelect(name: string) {
    const trimmedName = name.trim();
    if (!trimmedName || creating) return;
    setCreating(true);
    try {
      const created = await onCreate(trimmedName);
      selectCategory(created.id);
    } catch {
      // Likely a duplicate from a race; fall back to any existing match.
      const existing = categories.find(
        (c) => c.name.toLowerCase() === trimmedName.toLowerCase(),
      );
      if (existing) selectCategory(existing.id);
    } finally {
      setCreating(false);
    }
  }

  function selectHighlighted() {
    if (highlight < matches.length) {
      selectCategory(matches[highlight].id);
    } else if (showCreate) {
      createAndSelect(trimmed);
    }
  }

  function onKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    switch (e.key) {
      case "ArrowDown":
        e.preventDefault();
        setOpen(true);
        setHighlight((h) => Math.min(h + 1, Math.max(optionCount - 1, 0)));
        break;
      case "ArrowUp":
        e.preventDefault();
        setHighlight((h) => Math.max(h - 1, 0));
        break;
      case "Enter":
        e.preventDefault();
        selectHighlighted();
        break;
      case "Escape":
        setOpen(false);
        break;
      case "Backspace":
        if (query === "" && value) clearCategory();
        break;
    }
  }

  return (
    <div ref={containerRef} className="relative flex flex-col gap-1.5">
      {selected && (
        <div className="flex flex-wrap gap-1.5">
          <span
            className="inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-medium"
            style={
              selected.color
                ? { borderColor: selected.color, color: selected.color }
                : undefined
            }
          >
            {selected.name}
            <button
              type="button"
              onClick={clearCategory}
              className="opacity-60 hover:opacity-100"
              aria-label={`Remove ${selected.name}`}
            >
              <X className="h-3 w-3" />
            </button>
          </span>
        </div>
      )}

      <Input
        value={query}
        onChange={(e) => {
          setQuery(e.target.value);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        onKeyDown={onKeyDown}
        placeholder={selected ? "Change category…" : "Search or create a category…"}
        role="combobox"
        aria-expanded={open}
        autoComplete="off"
      />

      {open && optionCount > 0 && (
        <ul className="absolute top-full z-10 mt-1 max-h-56 w-full overflow-auto rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-background)] py-1 shadow-md">
          {matches.map((c, i) => (
            <li key={c.id}>
              <button
                type="button"
                onMouseEnter={() => setHighlight(i)}
                onClick={() => selectCategory(c.id)}
                className={`flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm ${
                  highlight === i ? "bg-[var(--color-muted)]" : ""
                }`}
              >
                {c.color && (
                  <span
                    className="h-2.5 w-2.5 shrink-0 rounded-full"
                    style={{ backgroundColor: c.color }}
                  />
                )}
                <span className="flex-1 truncate">{c.name}</span>
                {value === c.id && <Check className="h-3.5 w-3.5" />}
              </button>
            </li>
          ))}
          {showCreate && (
            <li>
              <button
                type="button"
                onMouseEnter={() => setHighlight(matches.length)}
                onClick={() => createAndSelect(trimmed)}
                disabled={creating}
                className={`flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm ${
                  highlight === matches.length ? "bg-[var(--color-muted)]" : ""
                }`}
              >
                <Plus className="h-3.5 w-3.5 shrink-0" />
                <span className="truncate">
                  Create “{trimmed}”
                </span>
              </button>
            </li>
          )}
        </ul>
      )}
    </div>
  );
}
