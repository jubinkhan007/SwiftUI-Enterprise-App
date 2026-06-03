import { useState } from "react";
import { Navigate } from "react-router-dom";
import { ShieldCheck } from "lucide-react";
import { useAuth } from "../auth/AuthContext";
import { Button, ErrorState, GlassCard } from "../components/ui";
import { Field, TextInput } from "../components/Modal";

export function LoginPage() {
  const { user, login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  if (user) return <Navigate to="/" replace />;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await login(email.trim().toLowerCase(), password);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign in failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 flex flex-col items-center gap-3 text-center">
          <div className="grid h-14 w-14 place-items-center rounded-2xl bg-gradient-to-br from-emerald to-primary text-white shadow-lg shadow-primary/30">
            <ShieldCheck size={26} />
          </div>
          <div>
            <h1 className="font-display text-xl font-bold text-ink">Enterprise Admin</h1>
            <p className="mt-1 text-sm text-muted">Sign in to the administration console</p>
          </div>
        </div>

        <GlassCard className="p-6">
          <form onSubmit={onSubmit} className="space-y-4">
            <Field label="Email">
              <TextInput
                type="email"
                autoComplete="username"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@company.com"
              />
            </Field>
            <Field label="Password">
              <TextInput
                type="password"
                autoComplete="current-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
              />
            </Field>
            {error && <ErrorState message={error} />}
            <Button type="submit" variant="primary" loading={loading} className="w-full">
              Sign in
            </Button>
          </form>
        </GlassCard>
        <p className="mt-6 text-center text-xs text-faint">
          Protected area · access is audited
        </p>
      </div>
    </div>
  );
}
