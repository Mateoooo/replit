import { Link } from "react-router-dom";
import type { ReactNode } from "react";

export function PageHeader({ rightSlot }: { rightSlot?: ReactNode }) {
  return (
    <div style={{ padding: "16px 16px 0 16px" }}>
      <header
        style={{
          minHeight: "64px",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "24px 40px",
          backgroundColor: "var(--color-card)",
          borderRadius: "12px",
          boxShadow: "0 1px 2px rgba(0, 0, 0, 0.05)",
        }}
      >
        <Link
          to="/"
          style={{
            display: "flex",
            alignItems: "center",
            gap: "12px",
            textDecoration: "none",
          }}
        >
          <div
            style={{
              width: "40px",
              height: "40px",
              borderRadius: "8px",
              backgroundColor: "var(--color-accent)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              color: "var(--color-text-on-accent)",
              fontFamily: "Jost, sans-serif",
              fontWeight: 500,
              fontSize: "18px",
            }}
          >
            R
          </div>
          <span
            style={{
              fontFamily: "Jost, sans-serif",
              fontWeight: 500,
              fontSize: "20px",
              color: "var(--color-text)",
            }}
          >
            Replit
          </span>
        </Link>

        {rightSlot && <div>{rightSlot}</div>}
      </header>
    </div>
  );
}