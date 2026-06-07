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
import { createTag } from "@/lib/hooks/use-transactions";
import { updateTag } from "@/lib/hooks/use-tags";
import type { Tag } from "@/lib/types/database";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** When set, the form edits this tag; otherwise it creates a new one. */
  tag?: Tag | null;
  onSaved?: () => void;
}

/** Create/edit modal for a tag (name only). */
export function TagForm({ open, onOpenChange, tag, onSaved }: Props) {
  const [name, setName] = useState("");
  const [submitError, setSubmitError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!open) return;
    setName(tag?.name ?? "");
    setSubmitError("");
  }, [open, tag]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmed = name.trim();
    if (!trimmed || submitting) return;
    setSubmitting(true);
    try {
      if (tag) {
        await updateTag(tag.id, trimmed);
      } else {
        await createTag(trimmed);
      }
      onOpenChange(false);
      onSaved?.();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Failed to save tag");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{tag ? "Edit tag" : "New tag"}</DialogTitle>
        </DialogHeader>
        <form onSubmit={onSubmit} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="tag_name">Name</Label>
            <Input
              id="tag_name"
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
