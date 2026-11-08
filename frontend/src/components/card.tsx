import type { CSSProperties, ReactNode } from "react";

export function Card({
  children,
  className = "",
  style,
}: {
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
}) {
  return (
    <div
      className={`bg-(--color-card) rounded-xl shadow-sm ${className}`}
      style={{ padding: 24, ...style }}
    >
      {children}
    </div>
  );
}
