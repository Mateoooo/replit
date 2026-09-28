import { forwardRef, type InputHTMLAttributes, type ReactNode } from "react";

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  hint?: string;
  rightSlot?: ReactNode;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  (
    { label, error, hint, rightSlot, className = "", disabled, ...props },
    ref,
  ) => {
    return (
      <div className="flex flex-col gap-2 w-full">
        {label && (
          <label className="text-sm text-(--color-caption)">{label}</label>
        )}

        <div
          className={`
            flex items-center
            w-full h-12
            rounded-xl border
            bg-(--color-input)
            transition-colors
            overflow-hidden
            ${
              error
                ? "border-(--color-error)"
                : "border-(--color-border)"
            }
            ${disabled ? "opacity-50 cursor-not-allowed" : ""}
          `}
        >
          <input
            ref={ref}
            disabled={disabled}
            className={`
              flex-1
              w-full
              h-full
              bg-transparent
              outline-none
              text-(--color-text)
              placeholder:text-(--color-caption)
              caret-(--color-text-link)
              ${className}
            `}
            style={{
              paddingLeft: "20px",
              paddingRight: rightSlot ? "8px" : "20px",
            }}
            {...props}
          />

          {rightSlot && (
            <div className="flex items-center justify-center w-12 h-full shrink-0">
              {rightSlot}
            </div>
          )}
        </div>

        {(error || hint) && (
          <span
            className={`
              text-xs
              ${error ? "text-(--color-error)" : ""}
            `}
          >
            {error || hint}
          </span>
        )}
      </div>
    );
  },
);

Input.displayName = "Input";