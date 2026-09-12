import React from 'react';

export const AuthBackground: React.FC = () => {
  return (
    <div className="fixed inset-0 overflow-hidden pointer-events-none bg-[#0b0f19] z-0">
      {/* Top Left Teal Orb */}
      <div 
        className="absolute -top-32 -left-20 w-96 h-96 rounded-full bg-[#14b8a6]/20 blur-[100px] animate-pulse"
        style={{ animationDuration: '8s' }}
      />
      
      {/* Bottom Right Violet Orb */}
      <div 
        className="absolute -bottom-32 -right-20 w-[450px] h-[450px] rounded-full bg-[#6366f1]/25 blur-[120px] animate-pulse"
        style={{ animationDuration: '10s' }}
      />

      {/* Center Subtle Brand Glow */}
      <div 
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] rounded-full bg-[#4f46e5]/10 blur-[150px]"
      />
    </div>
  );
};
