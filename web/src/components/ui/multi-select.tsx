import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { Check, ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils/cn";

export interface MultiSelectOption {
  value: string;
  label: string;
  /** Optional dot color, e.g. for categories. */
  color?: string | null;
}

interface Props {
  /** Shown on the trigger when nothing is selected, e.g. "All types". */
  placeholder: string;
  options: MultiSelectOption[];
  value: string[];
  onChange: (value: string[]) => void;
  className?: string;
}

/**
 * A dropdown that lets the user pick several values at once. The trigger mirrors
 * the single Select trigger and summarizes the current selection. Built on a
 * portalled Radix menu so it escapes the filter popover's scroll/overflow.
 */
export function MultiSelect({
  placeholder,
  options,
  value,
  onChange,
  className,
}: Props) {
  const selected = new Set(value);

  function toggle(v: string) {
    onChange(selected.has(v) ? value.filter((x) => x !== v) : [...value, v]);
  }

  // Summarize: the single label when one is picked, otherwise "N selected".
  const summary =
    value.length === 0
      ? placeholder
      : value.length === 1
        ? options.find((o) => o.value === value[0])?.label ?? placeholder
        : `${value.length} selected`;

  return (
    <DropdownMenu.Root>
      <DropdownMenu.Trigger
        className={cn(
          "flex h-10 w-full items-center justify-between gap-2 rounded-[var(--radius)] border border-[var(--color-input)] bg-[var(--color-background)] px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--color-ring)]",
          value.length === 0 && "text-[var(--color-muted-foreground)]",
          className,
        )}
      >
        <span className="truncate">{summary}</span>
        <ChevronDown className="h-4 w-4 shrink-0 opacity-60" />
      </DropdownMenu.Trigger>
      <DropdownMenu.Portal>
        <DropdownMenu.Content
          align="start"
          sideOffset={4}
          className="z-50 max-h-64 min-w-[var(--radix-dropdown-menu-trigger-width)] overflow-auto rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-card)] p-1 text-[var(--color-card-foreground)] shadow-md"
        >
          {options.length === 0 ? (
            <div className="px-3 py-2 text-sm text-[var(--color-muted-foreground)]">
              No options
            </div>
          ) : (
            options.map((opt) => {
              const checked = selected.has(opt.value);
              return (
                <DropdownMenu.CheckboxItem
                  key={opt.value}
                  checked={checked}
                  // Keep the menu open so several values can be toggled at once.
                  onSelect={(e) => {
                    e.preventDefault();
                    toggle(opt.value);
                  }}
                  className="relative flex cursor-pointer select-none items-center gap-2 rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none data-[highlighted]:bg-[var(--color-muted)]"
                >
                  <span className="absolute left-2 flex h-3.5 w-3.5 items-center justify-center">
                    {checked && <Check className="h-4 w-4" />}
                  </span>
                  {opt.color && (
                    <span
                      className="h-2.5 w-2.5 shrink-0 rounded-full"
                      style={{ backgroundColor: opt.color }}
                    />
                  )}
                  <span className="truncate">{opt.label}</span>
                </DropdownMenu.CheckboxItem>
              );
            })
          )}
        </DropdownMenu.Content>
      </DropdownMenu.Portal>
    </DropdownMenu.Root>
  );
}
