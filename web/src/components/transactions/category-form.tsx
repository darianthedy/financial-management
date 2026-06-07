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
import { createCategory } from "@/lib/hooks/use-transactions";
import type { Category } from "@/lib/types/database";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Prefills the name field, e.g. carried over from a search query. */
  defaultName?: string;
  onSaved?: (category: Category) => void;
}

/** Minimal modal to create a category on the fly from the transaction form. */
export function CategoryForm({
  open,
  onOpenChange,
  defaultName = "",
  onSaved,
}: Props) {
  const [name, setName] = useState(defaultName);
  const [submitError, setSubmitError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!open) return;
    setName(defaultName);
    setSubmitError("");
  }, [open, defaultName]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmed = name.trim();
    if (!trimmed || submitting) return;
    setSubmitting(true);
    try {
      const category = await createCategory(trimmed);
      onOpenChange(false);
      onSaved?.(category);
    } catch (err) {
      setSubmitError(
        err instanceof Error ? err.message : "Failed to create category",
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New category</DialogTitle>
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
