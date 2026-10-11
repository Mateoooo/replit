import { useEffect, useRef, useState } from "react";
import { API_URL, fetchWithRefresh, getLogsApi } from "../services/api";
import { getCookie } from "../services/utils/cookie";
import type { LogEntry } from "../services/types";

export type LogMode = "polling" | "websocket";

const PAGE = 500; // столько строк максимум отдаёт бэк за один запрос

function merge(prev: LogEntry[], incoming: LogEntry[]): LogEntry[] {
  if (incoming.length === 0) return prev;
  const map = new Map(prev.map((l) => [l.id, l]));
  incoming.forEach((l) => map.set(l.id, l));
  return [...map.values()].sort((a, b) => a.id - b.id);
}

/**
 * Логи запуска двумя способами:
 *  - polling:   раз в секунду GET /runs/:id/logs?after_id=<последний id>
 *  - websocket: подписка на RunLogsChannel (ActionCable), новые строки приходят сами
 */
export function useRunLogs(runId: number | null, mode: LogMode, active: boolean) {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [connected, setConnected] = useState(false);
  const activeRef = useRef(active);

  useEffect(() => {
    activeRef.current = active;
  }, [active]);

  // ---- Вариант 1: polling ----
  useEffect(() => {
    if (runId == null || mode !== "polling") return;

    setLogs([]);
    setConnected(false);
    let stopped = false;
    let timer: number | undefined;
    let lastId = 0;

    const tick = async () => {
      let delay = 1000;
      try {
        const data = await getLogsApi(runId, lastId);
        if (stopped) return;
        if (data.logs.length > 0) {
          lastId = data.lastId ?? lastId;
          setLogs((prev) => merge(prev, data.logs));
        }
        if (data.logs.length >= PAGE) delay = 0; // есть ещё — забираем сразу
        else if (data.logs.length === 0 && !activeRef.current) return; // запуск завершён, всё прочитано
      } catch {
        delay = 3000;
      }
      if (!stopped) timer = window.setTimeout(tick, delay);
    };
    tick();

    return () => {
      stopped = true;
      window.clearTimeout(timer);
    };
  }, [runId, mode]);

  // ---- Вариант 2: WebSocket (ActionCable) ----
  useEffect(() => {
    if (runId == null || mode !== "websocket") return;

    setLogs([]);
    setConnected(false);
    let closed = false;
    let ws: WebSocket | null = null;

    // Подписались -> догружаем то, что было до подключения
    const loadBacklog = async () => {
      let lastId = 0;
      for (;;) {
        const data = await getLogsApi(runId, lastId);
        if (closed) return;
        setLogs((prev) => merge(prev, data.logs));
        if (data.logs.length < PAGE) break;
        lastId = data.lastId ?? lastId;
      }
    };

    (async () => {
      try {
        // дёргаем защищённый эндпоинт: при необходимости обновит access-токен
        await fetchWithRefresh<unknown>("me");
      } catch {
        return;
      }
      if (closed) return;

      const wsUrl = API_URL.replace(/^http/, "ws");
      const token = encodeURIComponent(getCookie("accessToken") ?? "");
      ws = new WebSocket(`${wsUrl}/cable?token=${token}`, "actioncable-v1-json");
      const identifier = JSON.stringify({ channel: "RunLogsChannel", run_id: runId });

      ws.onopen = () => {
        ws?.send(JSON.stringify({ command: "subscribe", identifier }));
      };
      ws.onmessage = (event) => {
        const msg = JSON.parse(event.data);
        if (msg.type === "confirm_subscription") {
          setConnected(true);
          loadBacklog().catch(() => {});
        } else if (msg.type === "reject_subscription") {
          setConnected(false);
        } else if (!msg.type && msg.message) {
          setLogs((prev) => merge(prev, [msg.message as LogEntry]));
        }
      };
      ws.onclose = () => setConnected(false);
    })();

    return () => {
      closed = true;
      ws?.close();
    };
  }, [runId, mode]);

  return { logs, connected };
}
