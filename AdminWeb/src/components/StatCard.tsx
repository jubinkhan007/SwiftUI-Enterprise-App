import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import { GlassCard } from "./ui";

export function StatCard({
  label,
  value,
  icon: Icon,
  accent = "primary",
  hint,
}: {
  label: string;
  value: ReactNode;
  icon: LucideIcon;
  accent?: "primary" | "emerald" | "amber" | "rose";
  hint?: string;
}) {
  const accentBg: Record<string, string> = {
    primary: "from-primary/25 to-primary/5 text-primary",
    emerald: "from-emerald/25 to-emerald/5 text-emerald",
    amber: "from-amber/25 to-amber/5 text-amber",
    rose: "from-rose/25 to-rose/5 text-rose",
  };
  return (
    <GlassCard hover className="p-5">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-medium uppercase tracking-wider text-faint">{label}</p>
          <p className="mt-2 font-display text-3xl font-bold tracking-tight text-ink">{value}</p>
          {hint && <p className="mt-1 text-xs text-muted">{hint}</p>}
        </div>
        <div
          className={`grid h-11 w-11 place-items-center rounded-xl bg-gradient-to-br ${accentBg[accent]}`}
        >
          <Icon size={20} />
        </div>
      </div>
    </GlassCard>
  );
}
