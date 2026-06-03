import type { ReactNode } from "react";
import { X } from "lucide-react";
import { Button } from "./ui";

export function Modal({
  open,
  title,
  onClose,
  children,
  footer,
}: {
  open: boolean;
  title: string;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
}) {
  if (!open) return null;
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
    >
      <div
        className="absolute inset-0 bg-black/55 backdrop-blur-sm"
        onClick={onClose}
        style={{ animation: "fade-rise .2s ease both" }}
      />
      <div className="glass animate-rise relative z-10 w-full max-w-lg rounded-2xl p-5">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="font-display text-lg font-semibold text-ink">{title}</h2>
          <button
            onClick={onClose}
            className="ring-focus rounded-lg p-1 text-muted transition hover:bg-white/10 hover:text-ink"
            aria-label="Close"
          >
            <X size={18} />
          </button>
        </div>
        <div className="space-y-4">{children}</div>
        {footer && <div className="mt-5 flex justify-end gap-2">{footer}</div>}
      </div>
    </div>
  );
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-xs font-medium text-muted">{label}</span>
      {children}
    </label>
  );
}

export function TextInput(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...props}
      className="ring-focus w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-ink placeholder:text-faint"
    />
  );
}

export function SelectInput(props: React.SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      {...props}
      className="ring-focus w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-ink"
    />
  );
}

export function ConfirmButton({
  label,
  onConfirm,
  variant = "danger",
  loading,
}: {
  label: string;
  onConfirm: () => void;
  variant?: "danger" | "primary";
  loading?: boolean;
}) {
  return (
    <Button variant={variant} loading={loading} onClick={onConfirm}>
      {label}
    </Button>
  );
}
