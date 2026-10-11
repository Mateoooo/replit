import { useEffect, useRef, useState, type FormEvent } from "react";
import { getCommandsApi, runCommandApi, errorMessage } from "../services/api";
import type { CommandExecution } from "../services/types";
import { Button } from "../shared/ui/Button";
import { Input } from "../shared/ui/Input/input";
import { Card } from "./card";

export function CommandConsole({
  runId,
  canRun,
}: {
  runId: number;
  canRun: boolean;
}) {
  const [history, setHistory] = useState<CommandExecution[]>([]);
  const [command, setCommand] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setHistory([]);
    setError(null);
    getCommandsApi(runId)
      .then((d) => setHistory(d.commands))
      .catch(() => {});
  }, [runId]);

  useEffect(() => {
    const el = boxRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [history]);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const cmd = command.trim();
    if (!cmd || busy) return;

    setBusy(true);
    setError(null);
    try {
      const { command: executed } = await runCommandApi(runId, cmd);
      setHistory((h) => [...h, executed]);
      setCommand("");
    } catch (err: any) {
      setError(errorMessage(err, "Не удалось выполнить команду"));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Card className="flex flex-col gap-4">
      <h3 className="font-jost font-medium text-xl text-(--color-text)">
        Консоль
      </h3>

      <div
        ref={boxRef}
        className="rounded-lg overflow-auto font-mono text-sm"
        style={{ background: "#101314", height: 260, padding: 16, lineHeight: 1.5 }}
      >
        {history.length === 0 ? (
          <span style={{ color: "#8f9b8a" }}>
            Введите команду, например: ls -la
          </span>
        ) : (
          history.map((h) => (
            <div key={h.id} style={{ marginBottom: 12 }}>
              <div style={{ color: "#abd27a" }}>$ {h.command}</div>
              <div
                style={{
                  color: h.status === "failed" ? "#f0a399" : "#d7e0d0",
                  whiteSpace: "pre-wrap",
                  wordBreak: "break-all",
                }}
              >
                {h.output}
              </div>
              {h.exitCode !== null && h.exitCode !== 0 && (
                <div style={{ color: "#8f9b8a" }}>код выхода: {h.exitCode}</div>
              )}
            </div>
          ))
        )}
      </div>

      <form onSubmit={submit} className="flex items-end gap-3">
        <div className="flex-1">
          <Input
            placeholder={
              canRun ? "bundle exec rails routes" : "Запуск не активен"
            }
            value={command}
            onChange={(e) => setCommand(e.target.value)}
            disabled={!canRun || busy}
          />
        </div>
        <Button
          type="submit"
          style={{ padding: "0 24px" }}
          disabled={!canRun || busy || !command.trim()}
        >
          {busy ? "Выполняется…" : "Выполнить"}
        </Button>
      </form>

      {error && (
        <p className="text-sm text-(--color-error)" role="alert">
          {error}
        </p>
      )}
    </Card>
  );
}
