import {
  LayoutDashboard,
  Wallet,
  ArrowLeftRight,
  PiggyBank,
  Receipt,
  CalendarClock,
  Tags,
  Shapes,
  Settings,
  type LucideIcon,
} from "lucide-react";

export interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
  /** Items not yet implemented render but route to a placeholder. */
  primary: boolean;
}

export const navItems: NavItem[] = [
  { to: "/dashboard", label: "Dashboard", icon: LayoutDashboard, primary: true },
  { to: "/accounts", label: "Accounts", icon: Wallet, primary: true },
  {
    to: "/transactions",
    label: "Transactions",
    icon: ArrowLeftRight,
    primary: true,
  },
  { to: "/budgets", label: "Budgets", icon: PiggyBank, primary: false },
  { to: "/categories", label: "Categories", icon: Shapes, primary: false },
  { to: "/tags", label: "Tags", icon: Tags, primary: false },
  {
    to: "/fixed-expenses",
    label: "Fixed Expenses",
    icon: Receipt,
    primary: false,
  },
  { to: "/scheduled", label: "Scheduled", icon: CalendarClock, primary: false },
  { to: "/settings", label: "Settings", icon: Settings, primary: false },
];
