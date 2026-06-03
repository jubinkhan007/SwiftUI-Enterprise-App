import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from "react";
import { Loader2, Search } from "lucide-react";

export function cn(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(Boolean).join(" ");
}

// ---- Card ----

export function GlassCard({
  children,
  className,
  hover,
}: {
  children: ReactNode;
  className?: string;
  hover?: boolean;
}) {
  return (
    <div className={cn("glass rounded-2xl", hover && "glass-hover", className)}>{children}</div>
  );
}

// ---- Button ----

type Variant = "primary" | "ghost" | "danger" | "subtle";

const variantClasses: Record<Variant, string> = {
  primary:
    "bg-primary/90 hover:bg-primary text-white shadow-lg shadow-primary/20 border border-primary/40",
  danger:
    "bg-rose/15 hover:bg-rose/25 text-rose border border-rose/30",
  subtle:
    "bg-white/5 hover:bg-white/10 text-ink border border-white/10",
  ghost: "bg-transparent hover:bg-white/5 text-muted hover:text-ink border border-transparent",
};

export function Button({
  variant = "subtle",
  loading,
  className,
  children,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; loading?: boolean }) {
  return (
    <button
      {...rest}
      disabled={rest.disabled || loading}
      className={cn(
        "ring-focus inline-flex items-center justify-center gap-2 rounded-xl px-3.5 py-2 text-sm font-medium transition active:scale-[0.97] disabled:cursor-not-allowed disabled:opacity-50",
        variantClasses[variant],
        className,
      )}
    >
      {loading && <Loader2 size={15} className="animate-spin" />}
      {children}
    </button>
  );
}

// ---- Badge ----

type Tone = "emerald" | "amber" | "rose" | "blue" | "slate";

const toneClasses: Record<Tone, string> = {
  emerald: "bg-emerald/15 text-emerald border-emerald/25",
  amber: "bg-amber/15 text-amber border-amber/25",
  rose: "bg-rose/15 text-rose border-rose/25",
  blue: "bg-primary/15 text-primary border-primary/25",
  slate: "bg-white/5 text-muted border-white/10",
};

export function Badge({ tone = "slate", children }: { tone?: Tone; children: ReactNode }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-medium",
        toneClasses[tone],
      )}
    >
      {children}
    </span>
  );
}

// ---- Spinner / states ----

export function Spinner({ className }: { className?: string }) {
  return <Loader2 size={18} className={cn("animate-spin text-muted", className)} />;
}

export function LoadingState({ label = "Loading…" }: { label?: string }) {
  return (
    <div className="flex items-center justify-center gap-2 py-16 text-sm text-muted">
      <Spinner /> {label}
    </div>
  );
}

export function EmptyState({ icon, title, hint }: { icon?: ReactNode; title: string; hint?: string }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 py-16 text-center">
      {icon && <div className="mb-1 text-faint">{icon}</div>}
      <p className="font-medium text-ink">{title}</p>
      {hint && <p className="max-w-sm text-sm text-muted">{hint}</p>}
    </div>
  );
}

export function ErrorState({ message }: { message: string }) {
  return (
    <div className="rounded-xl border border-rose/30 bg-rose/10 px-4 py-3 text-sm text-rose">
      {message}
    </div>
  );
}

// ---- Search input ----

export function SearchInput({
  className,
  ...rest
}: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div className={cn("relative", className)}>
      <Search
        size={15}
        className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-faint"
      />
      <input
        {...rest}
        className="ring-focus w-full rounded-xl border border-white/10 bg-white/5 py-2 pl-9 pr-3 text-sm text-ink placeholder:text-faint"
      />
    </div>
  );
}

// ---- Page header ----

export function PageHeader({
  title,
  subtitle,
  actions,
}: {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 className="font-display text-2xl font-bold tracking-tight text-ink">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-muted">{subtitle}</p>}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}

// ---- Table ----

export function Table({ children }: { children: ReactNode }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse text-sm">{children}</table>
    </div>
  );
}

export function Th({ children, className }: { children?: ReactNode; className?: string }) {
  return (
    <th
      className={cn(
        "border-b border-white/8 px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-faint",
        className,
      )}
    >
      {children}
    </th>
  );
}

export function Td({
  children,
  className,
  title,
}: {
  children?: ReactNode;
  className?: string;
  title?: string;
}) {
  return (
    <td title={title} className={cn("border-b border-white/5 px-4 py-3 align-middle", className)}>
      {children}
    </td>
  );
}
