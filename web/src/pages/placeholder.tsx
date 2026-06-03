import { EmptyState } from "@/components/ui/misc";

export default function PlaceholderPage({ title }: { title: string }) {
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">{title}</h1>
      <EmptyState
        title="Coming soon"
        description={`The ${title} feature hasn't been built yet.`}
      />
    </div>
  );
}
