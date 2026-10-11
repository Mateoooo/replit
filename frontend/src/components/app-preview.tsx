import { useState, type ReactNode } from "react";
import { useAppReady } from "../hooks/use-app-ready";
import type { Run } from "../services/types";
import { Button } from "../shared/ui/Button";
import { Card } from "./card";

function Spinner({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="flex-1 flex flex-col items-center justify-center gap-4 text-center">
      <div
        className="animate-spin rounded-full"
        style={{
          width: 40,
          height: 40,
          border: "4px solid var(--color-border)",
          borderTopColor: "var(--color-accent)",
        }}
      />
      <p className="font-jost font-medium text-lg text-(--color-text)">{title}</p>
      {hint && <p className="text-sm text-(--color-caption) max-w-100">{hint}</p>}
    </div>
  );
}

function Placeholder({
  title,
  children,
}: {
  title: string;
  children?: ReactNode;
}) {
  return (
    <div
      className="flex-1 flex flex-col items-center justify-center gap-4 text-center"
      style={{ padding: 16, minHeight: 0 }}
    >
      <p className="font-jost font-medium text-lg text-(--color-text)">{title}</p>
      {children}
    </div>
  );
}

export function AppPreview({
  run,
  onStart,
}: {
  run: Run | null;
  onStart: () => void;
}) {
  const url = run?.status === "running" ? run.previewUrl : null;
  const ready = useAppReady(url);
  const [reloadKey, setReloadKey] = useState(0);

  let body: ReactNode;
  if (!run) {
    body = (
      <Placeholder title="Проект ещё не запускался">
        <Button onClick={onStart} style={{ padding: "0 24px" }}>Запустить</Button>
      </Placeholder>
    );
  } else if (run.status === "pending") {
    body = (
      <Spinner
        title="Распаковка и сборка образа…"
        hint="При первом запуске это может занять несколько минут — ход сборки виден в логах справа."
      />
    );
  } else if (run.status === "running") {
    body = !url ? (
      <Spinner title="Запуск контейнера…" />
    ) : !ready ? (
      <Spinner
        title="Приложение запускается…"
        hint="Rails поднимается внутри контейнера, это занимает несколько секунд."
      />
    ) : (
      <iframe
        key={reloadKey}
        src={url}
        title="Запущенный проект"
        className="flex-1 w-full rounded-lg border border-(--color-border)"
        style={{ background: "#fff", minHeight: 0 }}
      />
    );
  } else if (run.status === "failed") {
    body = (
      <Placeholder title="Запуск завершился с ошибкой">
        {run.errorMessage && (
          <pre
            className="text-xs text-(--color-error) overflow-auto max-w-full text-left rounded-lg bg-(--color-input)"
            style={{ padding: 12, maxHeight: 240, whiteSpace: "pre-wrap" }}
          >
            {run.errorMessage}
          </pre>
        )}
        <Button onClick={onStart} style={{ padding: "0 24px" }}>Запустить снова</Button>
      </Placeholder>
    );
  } else {
    body = (
      <Placeholder title="Проект остановлен">
        <Button onClick={onStart} style={{ padding: "0 24px" }}>Запустить</Button>
      </Placeholder>
    );
  }

  return (
    <Card className="flex flex-col gap-3 h-full min-h-100" style={{ padding: 16 }}>
      <div className="flex items-center justify-between gap-3">
        <span className="text-sm text-(--color-caption) truncate">
          {url ?? "Предпросмотр"}
        </span>
        {url && ready && (
          <div className="flex gap-2 shrink-0">
            <Button
              variant="text"
              style={{ height: 32, padding: "0 12px" }}
              onClick={() => setReloadKey((k) => k + 1)}
            >
              Обновить
            </Button>
            <Button
              variant="text"
              style={{ height: 32, padding: "0 12px" }}
              onClick={() => window.open(url, "_blank")}
            >
              В новой вкладке ↗
            </Button>
          </div>
        )}
      </div>
      {body}
    </Card>
  );
}
