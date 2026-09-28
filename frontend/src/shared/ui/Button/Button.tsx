import {type ButtonHTMLAttributes, type ReactNode } from "react";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "text";
  children: ReactNode;
}

const variantStyles = {
  primary:
    "bg-[var(--color-accent)] text-[var(--color-text-on-accent)] hover:bg-[var(--color-button-hover)] active:bg-[var(--color-button-pressed)] disabled:bg-[var(--color-disabled)] disabled:text-[var(--color-text-disabled)]",
  secondary:
    "bg-[var(--color-card)] border-2 border-[var(--color-accent)] text-[var(--color-text)] hover:bg-[var(--color-button-hover)] active:bg-[var(--color-button-pressed)] active:text-white",
  text: "bg-transparent text-[var(--color-text)] hover:text-[var(--color-accent)] active:text-[var(--color-button-pressed)] hover:underline underline-offset-2",
};

export function Button({
  variant = "primary",
  className = "",
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      className={`rounded-xl h-12 px-6 font-medium transition-colors cursor-pointer disabled:cursor-not-allowed ${variantStyles[variant]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}