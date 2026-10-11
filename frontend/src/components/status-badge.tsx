import type { ProjectStatus, RunStatus } from "../services/types";

type Tone = "green" | "gray" | "red" | "blue";

const TONES: Record<Tone, { dot: string; text: string; bg: string }> = {
  green: { dot: "#22c55e", text: "#166534", bg: "#dcfce7" },
  gray: { dot: "#94a3b8", text: "#475569", bg: "#f1f5f9" },
  red: { dot: "#ef4444", text: "#991b1b", bg: "#fee2e2" },
  blue: { dot: "#3b82f6", text: "#1e40af", bg: "#dbeafe" },
};

const PROJECT: Record<ProjectStatus, { label: string; tone: Tone }> = {
  running: { label: "Запущен", tone: "green" },
  stopped: { label: "Остановлен", tone: "gray" },
  failed: { label: "Ошибка", tone: "red" },
  created: { label: "Создан", tone: "blue" },
};

const RUN: Record<RunStatus, { label: string; tone: Tone }> = {
  pending: { label: "Подготовка", tone: "blue" },
  running: { label: "Работает", tone: "green" },
  finished: { label: "Завершён", tone: "gray" },
  failed: { label: "Ошибка", tone: "red" },
  stopped: { label: "Остановлен", tone: "gray" },
};

function Badge({ label, tone }: { label: string; tone: Tone }) {
  const c = TONES[tone];
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 6,
        padding: "4px 10px",
        borderRadius: 999,
        fontSize: 12,
        fontWeight: 500,
        whiteSpace: "nowrap",
        backgroundColor: c.bg,
        color: c.text,
      }}
    >
      <span
        style={{ width: 8, height: 8, borderRadius: "50%", backgroundColor: c.dot }}
      />
      {label}
    </span>
  );
}

export function StatusBadge({ status }: { status: ProjectStatus }) {
  return <Badge {...PROJECT[status]} />;
}

export function RunStatusBadge({ status }: { status: RunStatus }) {
  return <Badge {...RUN[status]} />;
}
