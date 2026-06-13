import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Plus, MoreVertical, Pencil, Trash2 } from "lucide-react";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { useCategories, deleteCategory } from "@/lib/hooks/use-categories";
import { CategoryForm } from "@/components/categories/category-form";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { CenteredSpinner, EmptyState } from "@/components/ui/misc";
import type { Category } from "@/lib/types/database";

export default function CategoriesPage() {
  const navigate = useNavigate();
  const { categories, loading, refetch } = useCategories();
  const [formOpen, setFormOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<Category | null>(null);

  function openCreate() {
    setEditTarget(null);
    setFormOpen(true);
  }

  function openEdit(category: Category) {
    setEditTarget(category);
    setFormOpen(true);
  }

  async function handleRemove(category: Category) {
    if (
      !confirm(
        `Delete "${category.name}"? Transactions using it will become uncategorized.`,
      )
    )
      return;
    await deleteCategory(category.id);
    refetch();
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Categories</h1>
        <Button onClick={openCreate}>
          <Plus className="h-4 w-4" />
          Add category
        </Button>
      </div>

      {loading ? (
        <CenteredSpinner />
      ) : categories.length === 0 ? (
        <EmptyState
          title="No categories yet"
          description="Create categories to classify your income and expenses."
          action={<Button onClick={openCreate}>Add category</Button>}
        />
      ) : (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          {categories.map((category) => (
            <Card
              key={category.id}
              className="cursor-pointer transition-shadow hover:shadow-md"
              onClick={() => navigate(`/transactions?cat=${category.id}`)}
            >
              <CardContent className="flex items-center justify-between gap-2 p-4">
                <div className="flex min-w-0 items-center gap-3">
                  <span
                    className="h-4 w-4 shrink-0 rounded-full"
                    style={{
                      backgroundColor:
                        category.color ?? "var(--color-muted-foreground)",
                    }}
                  />
                  <span className="truncate font-medium">{category.name}</span>
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
                      onClick={(e) => e.stopPropagation()}
                      className="z-50 min-w-36 rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-card)] p-1 shadow-md"
                    >
                      <DropdownMenu.Item
                        className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm outline-none data-[highlighted]:bg-[var(--color-muted)]"
                        onSelect={() => openEdit(category)}
                      >
                        <Pencil className="h-4 w-4" /> Edit
                      </DropdownMenu.Item>
                      <DropdownMenu.Item
                        className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm text-[var(--color-danger)] outline-none data-[highlighted]:bg-[var(--color-muted)]"
                        onSelect={() => handleRemove(category)}
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

      <CategoryForm
        open={formOpen}
        onOpenChange={setFormOpen}
        category={editTarget}
        onSaved={refetch}
      />
    </div>
  );
}
