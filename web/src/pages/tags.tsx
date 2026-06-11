import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Plus, MoreVertical, Pencil, Trash2, Tag as TagIcon } from "lucide-react";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { useTags, deleteTag } from "@/lib/hooks/use-tags";
import { TagForm } from "@/components/tags/tag-form";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { CenteredSpinner, EmptyState } from "@/components/ui/misc";
import type { Tag } from "@/lib/types/database";

export default function TagsPage() {
  const navigate = useNavigate();
  const { tags, loading, refetch } = useTags();
  const [formOpen, setFormOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<Tag | null>(null);

  function openCreate() {
    setEditTarget(null);
    setFormOpen(true);
  }

  function openEdit(tag: Tag) {
    setEditTarget(tag);
    setFormOpen(true);
  }

  async function handleRemove(tag: Tag) {
    if (
      !confirm(
        `Delete "${tag.name}"? It will be removed from any transactions using it.`,
      )
    )
      return;
    await deleteTag(tag.id);
    refetch();
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Tags</h1>
        <Button onClick={openCreate}>
          <Plus className="h-4 w-4" />
          Add tag
        </Button>
      </div>

      {loading ? (
        <CenteredSpinner />
      ) : tags.length === 0 ? (
        <EmptyState
          title="No tags yet"
          description="Create tags to label transactions across categories."
          action={<Button onClick={openCreate}>Add tag</Button>}
        />
      ) : (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          {tags.map((tag) => (
            <Card
              key={tag.id}
              className="cursor-pointer transition-shadow hover:shadow-md"
              onClick={() => navigate(`/transactions?tag=${tag.id}`)}
            >
              <CardContent className="flex items-center justify-between gap-2 p-4">
                <div className="flex min-w-0 items-center gap-2">
                  <TagIcon className="h-4 w-4 shrink-0 text-[var(--color-muted-foreground)]" />
                  <span className="truncate font-medium">{tag.name}</span>
                </div>
                <DropdownMenu.Root>
                  <DropdownMenu.Trigger
                    className="rounded p-1 hover:bg-[var(--color-muted)]"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <MoreVertical className="h-4 w-4 text-[var(--color-muted-foreground)]" />
                  </DropdownMenu.Trigger>
                  <DropdownMenu.Portal>
                    <DropdownMenu.Content
                      sideOffset={4}
                      align="end"
                      className="z-50 min-w-36 rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-card)] p-1 shadow-md"
                    >
                      <DropdownMenu.Item
                        className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm outline-none data-[highlighted]:bg-[var(--color-muted)]"
                        onSelect={() => openEdit(tag)}
                      >
                        <Pencil className="h-4 w-4" /> Edit
                      </DropdownMenu.Item>
                      <DropdownMenu.Item
                        className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm text-[var(--color-danger)] outline-none data-[highlighted]:bg-[var(--color-muted)]"
                        onSelect={() => handleRemove(tag)}
                      >
                        <Trash2 className="h-4 w-4" /> Delete
                      </DropdownMenu.Item>
                    </DropdownMenu.Content>
                  </DropdownMenu.Portal>
                </DropdownMenu.Root>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <TagForm
        open={formOpen}
        onOpenChange={setFormOpen}
        tag={editTarget}
        onSaved={refetch}
      />
    </div>
  );
}
