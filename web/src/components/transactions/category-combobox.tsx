import { useEffect, useMemo, useRef, useState } from "react";
import { Check, Plus, X } from "lucide-react";
import { Input } from "@/components/ui/input";
import type { Category } from "@/lib/types/database";

interface Props {
  categories: Category[];
  value: string[];
  onChange: (ids: string[]) => void;
  /** Persists a brand-new category and returns the created row. */
  onCreate: (name: string) => Promise<Category>;
}

/**
 * Autocomplete + create combobox for categories. Typing filters existing
 * categories; selecting one adds it as a chip. If the typed name has no exact
 * match, an inline "Create" option persists a new category on the fly.
 * Supports multiple categories (the data model is many-to-many).
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
  const selected = value.map((id) => byId.get(id)).filter(Boolean) as Category[];

  const trimmed = query.trim();
  const matches = useMemo(() => {
    const q = trimmed.toLowerCase();
    return categories.filter(
      (c) => !value.includes(c.id) && (!q || c.name.toLowerCase().includes(q)),
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

  function addCategory(id: string) {
    if (!value.includes(id)) onChange([...value, id]);
    setQuery("");
    setOpen(true);
  }

  function removeCategory(id: string) {
    onChange(value.filter((v) => v !== id));
  }

  async function createAndAdd(name: string) {
    const trimmedName = name.trim();
    if (!trimmedName || creating) return;
    setCreating(true);
    try {
      const created = await onCreate(trimmedName);
      addCategory(created.id);
    } catch {
      // Likely a duplicate from a race; fall back to any existing match.
      const existing = categories.find(
        (c) => c.name.toLowerCase() === trimmedName.toLowerCase(),
      );
      if (existing) addCategory(existing.id);
    } finally {
      setCreating(false);
    }
  }

  function selectHighlighted() {
    if (highlight < matches.length) {
      addCategory(matches[highlight].id);
    } else if (showCreate) {
      createAndAdd(trimmed);
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
        if (query === "" && value.length > 0) {
          removeCategory(value[value.length - 1]);
        }
        break;
    }
  }

  return (
    <div ref={containerRef} className="relative flex flex-col gap-1.5">
      {selected.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {selected.map((c) => (
            <span
              key={c.id}
              className="inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-medium"
              style={
                c.color
                  ? { borderColor: c.color, color: c.color }
                  : undefined
              }
            >
              {c.name}
              <button
                type="button"
                onClick={() => removeCategory(c.id)}
                className="opacity-60 hover:opacity-100"
                aria-label={`Remove ${c.name}`}
              >
                <X className="h-3 w-3" />
              </button>
            </span>
          ))}
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
        placeholder="Search or create a category…"
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
                onClick={() => addCategory(c.id)}
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
                {value.includes(c.id) && <Check className="h-3.5 w-3.5" />}
              </button>
            </li>
          ))}
          {showCreate && (
            <li>
              <button
                type="button"
                onMouseEnter={() => setHighlight(matches.length)}
                onClick={() => createAndAdd(trimmed)}
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
