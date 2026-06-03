import { Loader2 } from "lucide-react";
import { cn } from "@/lib/utils/cn";

export function Spinner({ className }: { className?: string }) {
  return (
    <Loader2
      className={cn(
        "h-5 w-5 animate-spin text-[var(--color-muted-foreground)]",
        className,
      )}
    />
  );
}

export function CenteredSpinner() {
  return (
    <div className="flex w-full items-center justify-center py-16">
      <Spinner className="h-6 w-6" />
    </div>
  );
}

export function Badge({
  className,
  ...props
}: React.HTMLAttributes<HTMLSpanElement>) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border border-[var(--color-border)] bg-[var(--color-muted)] px-2 py-0.5 text-xs font-medium text-[var(--color-muted-foreground)]",
        className,
      )}
      {...props}
    />
  );
}

export function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 rounded-[var(--radius)] border border-dashed border-[var(--color-border)] py-16 text-center">
      <p className="font-medium">{title}</p>
      {description && (
        <p className="max-w-sm text-sm text-[var(--color-muted-foreground)]">
          {description}
        </p>
      )}
      {action && <div className="mt-2">{action}</div>}
    </div>
  );
}
