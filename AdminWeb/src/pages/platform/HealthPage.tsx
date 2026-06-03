import { useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  Activity,
  Cpu,
  Database,
  Radio,
  Server,
  Users,
  Building2,
  MessagesSquare,
} from "lucide-react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { api } from "../../lib/api";
import type { ServerHealth } from "../../types";
import { ErrorState, GlassCard, LoadingState, PageHeader } from "../../components/ui";
import { StatCard } from "../../components/StatCard";
import { formatNumber, formatUptime } from "../../lib/format";

interface Sample {
  t: string;
  connections: number;
  memory: number;
  latency: number;
}

const MAX_SAMPLES = 30;

export function HealthPage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ["admin", "health"],
    queryFn: () => api<ServerHealth>("/admin/health"),
    refetchInterval: 5000,
  });

  const [history, setHistory] = useState<Sample[]>([]);
  const lastTs = useRef<string>("");

  useEffect(() => {
    if (!data || data.timestamp === lastTs.current) return;
    lastTs.current = data.timestamp;
    setHistory((prev) => {
      const next = [
        ...prev,
        {
          t: new Date(data.timestamp).toLocaleTimeString(undefined, { hour12: false }),
          connections: data.total_connections,
          memory: Math.round(data.memory_used_mb),
          latency: Math.round(data.db_latency_ms * 100) / 100,
        },
      ];
      return next.slice(-MAX_SAMPLES);
    });
  }, [data]);

  if (isLoading) return <LoadingState label="Reading server metrics…" />;
  if (error) return <ErrorState message={(error as Error).message} />;
  if (!data) return null;

  return (
    <div>
      <PageHeader
        title="Server Health"
        subtitle="Live process & datastore metrics · refreshes every 5s"
        actions={
          <span className="flex items-center gap-2 rounded-full border border-emerald/25 bg-emerald/10 px-3 py-1 text-xs font-medium text-emerald">
            <span className="h-2 w-2 animate-pulse rounded-full bg-emerald" /> {data.status.toUpperCase()}
          </span>
        }
      />

      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="Uptime" value={formatUptime(data.uptime_seconds)} icon={Server} accent="emerald" />
        <StatCard label="Memory (RSS)" value={`${data.memory_used_mb.toFixed(0)} MB`} icon={Cpu} accent="primary" />
        <StatCard label="DB latency" value={`${data.db_latency_ms.toFixed(2)} ms`} icon={Database} accent="amber" />
        <StatCard label="WS connections" value={formatNumber(data.total_connections)} icon={Radio} accent="primary" />
      </div>

      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="Connected users" value={formatNumber(data.unique_users)} icon={Users} />
        <StatCard label="Active channels" value={formatNumber(data.active_channels)} icon={Activity} />
        <StatCard label="Organizations" value={formatNumber(data.org_count)} icon={Building2} accent="emerald" />
        <StatCard label="Messages" value={formatNumber(data.message_count)} icon={MessagesSquare} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <GlassCard className="p-5">
          <h3 className="mb-4 font-display text-sm font-semibold text-ink">WebSocket connections</h3>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={history} margin={{ left: -20, right: 8 }}>
              <defs>
                <linearGradient id="connFill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#3b82f6" stopOpacity={0.5} />
                  <stop offset="100%" stopColor="#3b82f6" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
              <XAxis dataKey="t" tick={{ fill: "#64748b", fontSize: 11 }} />
              <YAxis allowDecimals={false} tick={{ fill: "#64748b", fontSize: 11 }} />
              <Tooltip contentStyle={tooltipStyle} />
              <Area type="monotone" dataKey="connections" stroke="#3b82f6" fill="url(#connFill)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </GlassCard>

        <GlassCard className="p-5">
          <h3 className="mb-4 font-display text-sm font-semibold text-ink">Memory & DB latency</h3>
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={history} margin={{ left: -20, right: 8 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
              <XAxis dataKey="t" tick={{ fill: "#64748b", fontSize: 11 }} />
              <YAxis tick={{ fill: "#64748b", fontSize: 11 }} />
              <Tooltip contentStyle={tooltipStyle} />
              <Line type="monotone" dataKey="memory" name="Memory (MB)" stroke="#34d399" strokeWidth={2} dot={false} />
              <Line type="monotone" dataKey="latency" name="Latency (ms)" stroke="#f59e0b" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </GlassCard>
      </div>
    </div>
  );
}

const tooltipStyle = {
  background: "rgba(14,20,34,0.95)",
  border: "1px solid rgba(255,255,255,0.1)",
  borderRadius: 12,
  color: "#e8edf6",
  fontSize: 12,
};
