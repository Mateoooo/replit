import { useEffect, useRef, useState } from "react";
import { useRunLogs, type LogMode } from "../hooks/use-run-logs";
import { formatTime } from "../services/utils/format";
import { Card } from "./card";

const STREAM_COLOR = {
  stdout: "#d7e0d0",
  stderr: "#f0a399",
  system: "#8f9b8a",
} as const;

// Занимает всю высоту родителя, логи прокручиваются внутри
export function LogViewer({ runId, active }: { runId: number; active: boolean }) {
  const [mode, setMode] = useState<LogMode>("polling");
  const { logs, connected } = useRunLogs(runId, mode, active);
  const boxRef = useRef<HTMLDivElement>(null);
  const stick = useRef(true);

  useEffect(() => {
    const el = boxRef.current;
    if (el && stick.current) el.scrollTop = el.scrollHeight;
  }, [logs]);

  const onScroll = () => {
    const el = boxRef.current;
    if (el) stick.current = el.scrollHeight - el.scrollTop - el.clientHeight < 40;
  };

  const tab = (value: LogMode, label: string) => (
    <button
      type="button"
      onClick={() => setMode(value)}
      className={`rounded-lg text-xs cursor-pointer transition-colors border ${
        mode === value
          ? "bg-(--color-accent) text-(--color-text-on-accent) border-(--color-accent)"
          : "bg-transparent text-(--color-caption) border-(--color-border) hover:border-(--color-accent)"
      }`}
      style={{ padding: "3px 10px" }}
    >
      {label}
    </button>
  );

  return (
    <Card className="flex flex-col gap-3 h-full min-h-100" style={{ padding: 16 }}>
      <div className="flex items-center justify-between gap-2 flex-wrap">
        <h3 className="font-jost font-medium text-lg text-(--color-text) flex items-center gap-2">
          Логи #{runId}
          {active && (
            <span className="text-xs font-normal text-(--color-text-link)">● в эфире</span>
          )}
        </h3>
        <div className="flex items-center gap-2">
          {mode === "websocket" && (
            <span className="text-xs text-(--color-caption)">
              {connected ? "подключено" : "подключение…"}
            </span>
          )}
          {tab("polling", "Polling")}
          {tab("websocket", "WebSocket")}
        </div>
      </div>

      <div
        ref={boxRef}
        onScroll={onScroll}
        className="flex-1 rounded-lg overflow-auto font-mono text-xs"
        style={{ background: "#101314", padding: 12, lineHeight: 1.5, minHeight: 0 }}
      >
        {logs.length === 0 ? (
          <span style={{ color: STREAM_COLOR.system }}>Логов пока нет…</span>
        ) : (
          logs.map((l) => (
            <div
              key={l.id}
              style={{
                color: STREAM_COLOR[l.stream],
                whiteSpace: "pre-wrap",
                wordBreak: "break-all",
              }}
            >
              <span style={{ color: "#5d6a5f" }}>{formatTime(l.loggedAt)} </span>
              {l.content}
            </div>
          ))
        )}
      </div>
    </Card>
  );
}
