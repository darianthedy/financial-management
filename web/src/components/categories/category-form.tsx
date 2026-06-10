import { useEffect, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input, Label, FieldError } from "@/components/ui/input";
import { createCategory, CATEGORY_COLORS } from "@/lib/hooks/use-transactions";
import { updateCategory } from "@/lib/hooks/use-categories";
import type { Category } from "@/lib/types/database";
import { cn } from "@/lib/utils/cn";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** When set, the form edits this category; otherwise it creates a new one. */
  category?: Category | null;
  onSaved?: () => void;
}

/** Create/edit modal for a category: name + a color swatch from the palette. */
export function CategoryForm({ open, onOpenChange, category, onSaved }: Props) {
  const [name, setName] = useState("");
  const [color, setColor] = useState<string>(CATEGORY_COLORS[0]);
  const [submitError, setSubmitError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!open) return;
    setName(category?.name ?? "");
    setColor(category?.color ?? CATEGORY_COLORS[0]);
    setSubmitError("");
  }, [open, category]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmed = name.trim();
    if (!trimmed || submitting) return;
    setSubmitting(true);
    try {
      if (category) {
        await updateCategory(category.id, { name: trimmed, color });
      } else {
        await createCategory(trimmed, color);
      }
      onOpenChange(false);
      onSaved?.();
    } catch (err) {
      setSubmitError(
        err instanceof Error ? err.message : "Failed to save category",
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{category ? "Edit category" : "New category"}</DialogTitle>
        </DialogHeader>
        <form onSubmit={onSubmit} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="category_name">Name</Label>
            <Input
              id="category_name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoFocus
            />
          </div>

          <div className="flex flex-col gap-1.5">
            <Label>Color</Label>
            <div className="flex flex-wrap items-center gap-2">
              {CATEGORY_COLORS.map((c) => (
                <button
                  key={c}
                  type="button"
                  aria-label={`Color ${c}`}
                  onClick={() => setColor(c)}
                  className={cn(
                    "h-7 w-7 rounded-full border-2 transition",
                    color === c
                      ? "border-[var(--color-foreground)] scale-110"
                      : "border-transparent",
                  )}
                  style={{ backgroundColor: c }}
                />
              ))}
              <label
                aria-label="Custom color"
                className={cn(
                  "relative h-7 w-7 cursor-pointer rounded-full border-2 transition",
                  !CATEGORY_COLORS.includes(color)
                    ? "border-[var(--color-foreground)] scale-110"
                    : "border-[var(--color-border)]",
                )}
                style={{
                  backgroundColor: CATEGORY_COLORS.includes(color)
                    ? "transparent"
                    : color,
                }}
              >
                {CATEGORY_COLORS.includes(color) && (
                  <span className="pointer-events-none absolute inset-0 flex items-center justify-center text-base leading-none text-[var(--color-muted-foreground)]">
                    +
                  </span>
                )}
                <input
                  type="color"
                  value={color}
                  onChange={(e) => setColor(e.target.value)}
                  className="absolute inset-0 h-full w-full cursor-pointer opacity-0"
                />
              </label>
            </div>
          </div>

          <FieldError message={submitError} />

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? "Saving…" : "Save"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
