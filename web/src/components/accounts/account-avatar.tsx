import { accountTypeIcon } from "@/lib/account-types";
import { cn } from "@/lib/utils/cn";
import type { AccountType } from "@/lib/types/database";

interface Props {
  type: AccountType;
  imageUrl?: string | null;
  name?: string;
  /** Sizing/positioning for the circular container (e.g. "h-10 w-10"). */
  className?: string;
  /** Sizing for the fallback type icon (e.g. "h-5 w-5"). */
  iconClassName?: string;
}

/** Circular account avatar: the uploaded image when set, else the type icon. */
export function AccountAvatar({
  type,
  imageUrl,
  name,
  className,
  iconClassName,
}: Props) {
  const Icon = accountTypeIcon(type);
  return (
    <div
      className={cn(
        "flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-[var(--color-muted)]",
        className,
      )}
    >
      {imageUrl ? (
        <img
          src={imageUrl}
          alt={name ? `${name} logo` : ""}
          className="h-full w-full object-contain p-1"
        />
      ) : (
        <Icon
          className={cn("text-[var(--color-muted-foreground)]", iconClassName)}
        />
      )}
    </div>
  );
}
