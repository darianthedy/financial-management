import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "@/lib/hooks/use-auth";
import { CenteredSpinner } from "@/components/ui/misc";

export function AuthGuard() {
  const { session, loading } = useAuth();

  if (loading) return <CenteredSpinner />;
  if (!session) return <Navigate to="/login" replace />;

  return <Outlet />;
}
