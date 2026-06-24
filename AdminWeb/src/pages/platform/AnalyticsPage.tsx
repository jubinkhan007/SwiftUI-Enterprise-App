import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  TrendingUp,
  Activity,
  Database,
  AlertTriangle,
  Clock,
  MessageSquare,
  Users,
  RefreshCw,
} from "lucide-react";
import { api } from "../../lib/api";
import {
  GlassCard,
  LoadingState,
  ErrorState,
  PageHeader,
  Button,
} from "../../components/ui";
import { StatCard } from "../../components/StatCard";
import { formatBytes, formatNumber } from "../../lib/format";
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
} from "recharts";

interface PlatformAnalytics {
  stats: {
    requests_per_second: number;
    average_latency_ms: number;
    error_rate: number;
    total_requests: number;
  };
  storage: {
    database_size: number;
    total_attachment_size: number;
    attachment_breakdown: {
      images: number;
      videos: number;
      documents: number;
      others: number;
    };
  };
  usage_trends: Array<{
    date: string;
    dau: number;
    mau: number;
    message_count: number;
    meeting_hours: number;
  }>;
}

export function AnalyticsPage() {
  const [refreshedAt, setRefreshedAt] = useState<Date>(new Date());

  // Poll performance statistics every 5 seconds for a "live" feel
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ["admin", "platform", "analytics"],
    queryFn: async () => {
      const res = await api<PlatformAnalytics>("/admin/analytics/platform");
      setRefreshedAt(new Date());
      return res;
    },
    refetchInterval: 5000,
  });

  if (isLoading) return <LoadingState label="Loading platform analytics…" />;
  if (error || !data) {
    return (
      <div className="space-y-4">
        <PageHeader title="Platform Analytics" subtitle="Performance and usage metrics" />
        <ErrorState message={error ? (error as Error).message : "Failed to load metrics."} />
        <Button onClick={() => refetch()}>Retry</Button>
      </div>
    );
  }

  const { stats, storage, usage_trends: usageTrends } = data;
  const totalStorage = storage.database_size + storage.total_attachment_size;
  const storageLimit = 50 * 1024 * 1024; // 50MB local dev threshold for demonstration
  const storagePercentage = Math.min((totalStorage / storageLimit) * 100, 100);

  // Formatter for Recharts tooltips
  const formatTooltipValue = (value: number | string) => {
    if (typeof value === "number") {
      return formatNumber(value);
    }
    return value;
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title="Platform Analytics"
        subtitle="Live server metrics, storage utilization, and usage activity"
        actions={
          <div className="flex items-center gap-3 text-xs text-muted">
            <span>Last update: {refreshedAt.toLocaleTimeString()}</span>
            <Button variant="ghost" className="p-2" onClick={() => refetch()}>
              <RefreshCw size={15} />
            </Button>
          </div>
        }
      />

      {/* 1. Vapor Live Throughput & Server Stats */}
      <h3 className="font-display text-lg font-semibold text-ink flex items-center gap-2">
        <Activity size={18} className="text-primary" />
        Vapor Server Performance (Live)
      </h3>
      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <div className="relative">
          <StatCard
            label="Throughput"
            value={`${stats.requests_per_second.toFixed(2)} RPS`}
            icon={Activity}
            accent="emerald"
          />
          {stats.requests_per_second > 0 && (
            <span className="absolute top-4 right-4 flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
          )}
        </div>
        <StatCard
          label="Average Response Latency"
          value={`${stats.average_latency_ms.toFixed(1)} ms`}
          icon={Clock}
          accent={stats.average_latency_ms > 200 ? "amber" : undefined}
        />
        <StatCard
          label="HTTP Error Rate"
          value={`${(stats.error_rate * 100).toFixed(1)}%`}
          icon={AlertTriangle}
          accent={stats.error_rate > 0.05 ? "rose" : undefined}
        />
        <StatCard
          label="Total HTTP Requests"
          value={formatNumber(stats.total_requests)}
          icon={TrendingUp}
          accent="primary"
        />
      </div>

      {/* 2. Storage Metrics Dashboard */}
      <h3 className="font-display text-lg font-semibold text-ink flex items-center gap-2 mt-8">
        <Database size={18} className="text-primary" />
        Storage Metrics & Capacity Limits
      </h3>
      <div className="grid gap-6 md:grid-cols-3">
        <GlassCard className="p-5 space-y-4 md:col-span-2">
          <h4 className="font-display text-sm font-semibold text-muted">Attachment Breakdown</h4>
          <div className="grid grid-cols-2 gap-6">
            <div className="space-y-4">
              <div>
                <div className="flex justify-between text-xs text-muted mb-1">
                  <span>Images</span>
                  <span className="font-semibold text-ink">{formatBytes(storage.attachment_breakdown.images)}</span>
                </div>
                <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-emerald-500 rounded-full"
                    style={{
                      width: `${
                        storage.total_attachment_size
                          ? (storage.attachment_breakdown.images / storage.total_attachment_size) * 100
                          : 0
                      }%`,
                    }}
                  />
                </div>
              </div>
              <div>
                <div className="flex justify-between text-xs text-muted mb-1">
                  <span>Videos & Audio</span>
                  <span className="font-semibold text-ink">{formatBytes(storage.attachment_breakdown.videos)}</span>
                </div>
                <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-amber-500 rounded-full"
                    style={{
                      width: `${
                        storage.total_attachment_size
                          ? (storage.attachment_breakdown.videos / storage.total_attachment_size) * 100
                          : 0
                      }%`,
                    }}
                  />
                </div>
              </div>
            </div>
            <div className="space-y-4">
              <div>
                <div className="flex justify-between text-xs text-muted mb-1">
                  <span>Documents & Text</span>
                  <span className="font-semibold text-ink">{formatBytes(storage.attachment_breakdown.documents)}</span>
                </div>
                <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-primary rounded-full"
                    style={{
                      width: `${
                        storage.total_attachment_size
                          ? (storage.attachment_breakdown.documents / storage.total_attachment_size) * 100
                          : 0
                      }%`,
                    }}
                  />
                </div>
              </div>
              <div>
                <div className="flex justify-between text-xs text-muted mb-1">
                  <span>Other Files</span>
                  <span className="font-semibold text-ink">{formatBytes(storage.attachment_breakdown.others)}</span>
                </div>
                <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-rose rounded-full"
                    style={{
                      width: `${
                        storage.total_attachment_size
                          ? (storage.attachment_breakdown.others / storage.total_attachment_size) * 100
                          : 0
                      }%`,
                    }}
                  />
                </div>
              </div>
            </div>
          </div>
        </GlassCard>

        <GlassCard className="p-5 flex flex-col justify-between">
          <div className="space-y-4">
            <h4 className="font-display text-sm font-semibold text-muted">Disk Utilization</h4>
            <div className="flex justify-between text-sm">
              <span className="text-muted">SQLite Database:</span>
              <span className="font-semibold text-ink">{formatBytes(storage.database_size)}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-muted">Total Attachments:</span>
              <span className="font-semibold text-ink">{formatBytes(storage.total_attachment_size)}</span>
            </div>
            <div className="border-t border-white/5 pt-3 flex justify-between text-sm font-semibold">
              <span className="text-ink">Total Storage Used:</span>
              <span className="text-ink">{formatBytes(totalStorage)}</span>
            </div>
          </div>

          <div className="mt-6 space-y-2">
            <div className="flex justify-between text-xs text-muted">
              <span>Limit: {formatBytes(storageLimit)}</span>
              <span>{storagePercentage.toFixed(1)}% Used</span>
            </div>
            <div className="h-2 w-full bg-white/5 rounded-full overflow-hidden">
              <div
                className={`h-full rounded-full transition-all ${
                  storagePercentage > 80 ? "bg-rose" : storagePercentage > 60 ? "bg-amber-500" : "bg-primary"
                }`}
                style={{ width: `${storagePercentage}%` }}
              />
            </div>
            {storagePercentage > 60 && (
              <div className="flex items-center gap-1.5 text-xs text-amber-400 mt-2">
                <AlertTriangle size={13} />
                <span>Approaching platform storage cap.</span>
              </div>
            )}
          </div>
        </GlassCard>
      </div>

      {/* 3. Usage Trends Graphs */}
      <h3 className="font-display text-lg font-semibold text-ink flex items-center gap-2 mt-8">
        <TrendingUp size={18} className="text-primary" />
        Platform Activity & Usage Trends (Past 30 Days)
      </h3>
      <div className="grid gap-6 md:grid-cols-2">
        {/* User Activity: DAU & MAU */}
        <GlassCard className="p-5 space-y-4">
          <h4 className="font-display text-sm font-semibold text-muted flex items-center gap-1.5">
            <Users size={16} /> User Activity (DAU vs MAU)
          </h4>
          <div className="h-[280px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={usageTrends} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorDau" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="var(--color-primary)" stopOpacity={0.2} />
                    <stop offset="95%" stopColor="var(--color-primary)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                <XAxis dataKey="date" stroke="rgba(255,255,255,0.3)" fontSize={11} />
                <YAxis stroke="rgba(255,255,255,0.3)" fontSize={11} />
                <Tooltip
                  contentStyle={{ backgroundColor: "#1e1e24", borderColor: "rgba(255,255,255,0.1)" }}
                  itemStyle={{ color: "#fff" }}
                  labelStyle={{ color: "#8a8a93" }}
                  formatter={formatTooltipValue}
                />
                <Legend />
                <Area
                  name="Daily Active (DAU)"
                  type="monotone"
                  dataKey="dau"
                  stroke="var(--color-primary)"
                  fillOpacity={1}
                  fill="url(#colorDau)"
                />
                <Line
                  name="Monthly Active (MAU)"
                  type="monotone"
                  dataKey="mau"
                  stroke="#a78bfa"
                  strokeWidth={2}
                  dot={false}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </GlassCard>

        {/* Messaging & Call Volume */}
        <GlassCard className="p-5 space-y-4">
          <h4 className="font-display text-sm font-semibold text-muted flex items-center gap-1.5">
            <MessageSquare size={16} /> Message Activity & Meeting Hours
          </h4>
          <div className="h-[280px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={usageTrends} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                <XAxis dataKey="date" stroke="rgba(255,255,255,0.3)" fontSize={11} />
                <YAxis yAxisId="left" stroke="rgba(255,255,255,0.3)" fontSize={11} />
                <YAxis yAxisId="right" orientation="right" stroke="rgba(255,255,255,0.3)" fontSize={11} />
                <Tooltip
                  contentStyle={{ backgroundColor: "#1e1e24", borderColor: "rgba(255,255,255,0.1)" }}
                  itemStyle={{ color: "#fff" }}
                  labelStyle={{ color: "#8a8a93" }}
                  formatter={formatTooltipValue}
                />
                <Legend />
                <Line
                  yAxisId="left"
                  name="Messages Sent"
                  type="monotone"
                  dataKey="message_count"
                  stroke="#10b981"
                  strokeWidth={2}
                  dot={false}
                />
                <Line
                  yAxisId="right"
                  name="Meeting Hours"
                  type="monotone"
                  dataKey="meeting_hours"
                  stroke="#f59e0b"
                  strokeWidth={2}
                  dot={false}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
