import React from 'react';

interface StatusBadgeProps {
  text: string;
  color?: string; // hex or tailwind class
  variant?: 'primary' | 'success' | 'warning' | 'error' | 'teal';
}

export const StatusBadge: React.FC<StatusBadgeProps> = ({
  text,
  variant = 'primary'
}) => {
  const styles = {
    primary: 'bg-[#4f46e5]/15 text-[#818cf8] border-[#4f46e5]/30',
    success: 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30',
    warning: 'bg-amber-500/15 text-amber-400 border-amber-500/30',
    error: 'bg-rose-500/15 text-rose-400 border-rose-500/30',
    teal: 'bg-[#14b8a6]/15 text-[#2dd4bf] border-[#14b8a6]/30',
  }[variant];

  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold border ${styles}`}>
      {text}
    </span>
  );
};

interface FilterChipProps {
  title: string;
  isSelected: boolean;
  onClick: () => void;
}

export const FilterChip: React.FC<FilterChipProps> = ({ title, isSelected, onClick }) => {
  return (
    <button
      onClick={onClick}
      className={`px-3 py-1.5 rounded-full text-xs font-semibold transition-all duration-200 cursor-pointer ${
        isSelected
          ? 'bg-[#4f46e5] text-white shadow-lg shadow-indigo-500/30 border border-indigo-400/50'
          : 'bg-[#1e293b]/70 text-slate-400 hover:text-slate-200 border border-slate-700/50 hover:bg-[#1e293b]'
      }`}
    >
      {title}
    </button>
  );
};
