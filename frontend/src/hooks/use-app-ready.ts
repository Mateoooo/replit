import { useEffect, useState } from "react";

// Контейнер уже запущен, но Rails внутри ещё стартует. Пробуем достучаться до
// приложения и сообщаем, когда оно начало отвечать (тогда можно показывать iframe).
export function useAppReady(url: string | null): boolean {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    setReady(false);
    if (!url) return;

    let stopped = false;
    let timer: number | undefined;

    const probe = async () => {
      try {
        await fetch(url, { mode: "no-cors", cache: "no-store" });
        if (!stopped) setReady(true);
      } catch {
        if (!stopped) timer = window.setTimeout(probe, 1500);
      }
    };
    probe();

    return () => {
      stopped = true;
      window.clearTimeout(timer);
    };
  }, [url]);

  return ready;
}
