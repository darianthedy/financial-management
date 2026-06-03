import {
  Landmark,
  CreditCard,
  Wallet,
  Banknote,
  Circle,
  type LucideIcon,
} from "lucide-react";
import type { AccountType } from "@/lib/types/database";

export const ACCOUNT_TYPES: { value: AccountType; label: string }[] = [
  { value: "bank_account", label: "Bank Account" },
  { value: "credit_card", label: "Credit Card" },
  { value: "digital_wallet", label: "Digital Wallet" },
  { value: "cash", label: "Cash" },
  { value: "other", label: "Other" },
];

const ICONS: Record<AccountType, LucideIcon> = {
  bank_account: Landmark,
  credit_card: CreditCard,
  digital_wallet: Wallet,
  cash: Banknote,
  other: Circle,
};

export function accountTypeIcon(type: AccountType): LucideIcon {
  return ICONS[type] ?? Circle;
}

export function accountTypeLabel(type: AccountType): string {
  return ACCOUNT_TYPES.find((t) => t.value === type)?.label ?? "Other";
}
