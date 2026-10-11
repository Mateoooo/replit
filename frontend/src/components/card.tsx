import type { CSSProperties, ReactNode } from "react";

// Отступы задаются inline: в global.css стоит `* { margin: 0; padding: 0 }`
// без @layer, и он перебивает Tailwind-утилиты p-* / m-* (gap-* при этом работает).
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
