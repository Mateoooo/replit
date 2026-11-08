#!/usr/bin/env node
// Стресс-тест платформы: имитирует N студентов, которые одновременно
// регистрируются, загружают проект, запускают его и работают с логами и консолью.
//
//   node scripts/stress.mjs --students=5 --zip=./app.zip
//   node scripts/stress.mjs --students=25 --zip-dir=./stress-zips --duration=300
//
// Параметры (все необязательные, кроме --zip или --zip-dir):
//   --base=http://localhost:3000   адрес бэкенда
//   --students=5                   сколько студентов
//   --zip=app.zip                  один архив для всех (Docker возьмёт сборку из кеша)
//   --zip-dir=папка                app-1.zip, app-2.zip... (см. make_variants.sh) — «настоящие» разные проекты
//   --duration=120                 сколько секунд «работают» после запуска проекта
//   --hold=120                     вместо --duration: все работают, пока последний студент не запустится,
//                                  и ещё столько секунд (так проверяется ПИК: все проекты запущены одновременно)
//   --ramp=0                       за сколько секунд студенты постепенно подключаются (0 = все сразу)
//   --startup-timeout=600          сколько секунд ждать, пока проект запустится
//   --preview-timeout=120          сколько секунд ждать ответа самого приложения
//   --no-start                     не запускать проекты (проверка только API без контейнеров)
//   --keep                         не удалять проекты и пользователей после теста
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";

const args = Object.fromEntries(
  process.argv.slice(2).map((arg) => {
    const match = arg.match(/^--([^=]+)(?:=(.*))?$/);
    return match ? [match[1], match[2] ?? true] : [arg, true];
  })
);
const BASE = String(args.base ?? "http://localhost:3000").replace(/\/$/, "");
const STUDENTS = Number(args.students ?? 5);
const DURATION = Number(args.duration ?? 120);
const RAMP = Number(args.ramp ?? 0);
const HOLD = args.hold === undefined ? null : Number(args.hold);
const STARTUP_TIMEOUT = Number(args["startup-timeout"] ?? 600);
const PREVIEW_TIMEOUT = Number(args["preview-timeout"] ?? 120);
const NO_START = Boolean(args["no-start"]);
const KEEP = Boolean(args.keep);
const ZIP = args.zip ? String(args.zip) : null;
const ZIP_DIR = args["zip-dir"] ? String(args["zip-dir"]) : null;
const RUN_ID = Date.now().toString(36);

if (!ZIP && !ZIP_DIR) {
  console.error("Укажите --zip=файл.zip или --zip-dir=папка (см. scripts/make_variants.sh)");
  process.exit(2);
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const now = () => performance.now();

// ---------- статистика ----------
const stats = new Map(); // "GET /projects" -> { ms: [], errors: 0, codes: Map }
function record(label, ms, status, error) {
  if (!stats.has(label)) stats.set(label, { ms: [], errors: 0, codes: new Map() });
  const entry = stats.get(label);
  entry.ms.push(ms);
  const code = error ? "сеть" : status;
  entry.codes.set(code, (entry.codes.get(code) ?? 0) + 1);
  if (error || status >= 400) entry.errors += 1;
}
const percentile = (values, p) => {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)];
};
const fmt = (ms) => (ms >= 1000 ? `${(ms / 1000).toFixed(1)} с` : `${Math.round(ms)} мс`);

// ---------- HTTP ----------
async function rawSend(student, method, pathname, json, form) {
  const headers = {};
  if (student.access) headers.authorization = `Bearer ${student.access}`;
  if (json !== undefined) headers["content-type"] = "application/json";
  return fetch(`${BASE}${pathname}`, {
    method,
    headers,
    body: json !== undefined ? JSON.stringify(json) : form,
    signal: AbortSignal.timeout(60_000),
  });
}

async function request(student, method, pathname, { json, form } = {}) {
  const label = `${method} ${pathname.split("?")[0].replace(/\d+/g, ":id")}`;
  const started = now();
  let res;
  try {
    res = await rawSend(student, method, pathname, json, form);
    if (res.status === 401 && student.refresh) {
      // access-токен живёт 15 минут: обновляем по refresh, как это делает фронтенд
      const refreshed = await fetch(`${BASE}/auth/token`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ token: student.refresh }),
      });
      if (refreshed.ok) {
        student.access = (await refreshed.json()).accessToken;
        student.refreshes += 1;
        res = await rawSend(student, method, pathname, json, form);
      }
    }
  } catch (error) {
    record(label, now() - started, 0, error);
    return { ok: false, status: 0, body: null, error: String(error?.message ?? error) };
  }
  const ms = now() - started;
  let body = null;
  try {
    body = await res.json();
  } catch {
    /* ответ без тела */
  }
  record(label, ms, res.status);
  return { ok: res.ok, status: res.status, body };
}

// ---------- виртуальный студент ----------
const phases = new Array(STUDENTS).fill("ожидание");
const results = [];
let startupDone = 0;   // сколько студентов уже прошли этап запуска (успешно или нет)
let allReadyAt = null; // момент, когда запуск прошли все
let liveNow = 0;       // сколько проектов работает прямо сейчас
let livePeak = 0;      // максимум одновременно работающих

async function zipBlob(i) {
  const file = ZIP_DIR ? `${ZIP_DIR}/app-${i + 1}.zip` : ZIP;
  if (!existsSync(file)) throw new Error(`Нет файла ${file}`);
  return new Blob([await readFile(file)], { type: "application/zip" });
}

function phaseOf(run) {
  if (run.status === "pending") return run.queued ? "в очереди" : "сборка";
  return run.status === "running" ? "работает" : run.status;
}

async function waitForRunning(student, index, startedAt) {
  while ((now() - startedAt) / 1000 < STARTUP_TIMEOUT) {
    const res = await request(student, "GET", `/projects/${student.projectId}/runs`);
    const run = res.body?.runs?.[0];
    if (run) {
      student.run = run;
      phases[index] = phaseOf(run);
      if (run.status === "running") return "running";
      if (["failed", "stopped", "finished"].includes(run.status)) {
        student.error = run.errorMessage ?? `запуск завершился: ${run.status}`;
        return run.status;
      }
    }
    await sleep(2000);
  }
  return "timeout";
}

async function waitForPreview(student, startedAt) {
  const url = student.run?.previewUrl;
  if (!url) return false;
  const deadline = now() + PREVIEW_TIMEOUT * 1000;
  while (now() < deadline) {
    const t = now();
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
      if (res.status < 500) {
        record("GET <приложение студента>", now() - t, res.status);
        return true;
      }
    } catch {
      /* приложение ещё запускается */
    }
    await sleep(2000);
  }
  return false;
}

async function work(student, index) {
  let cursor = 0;
  let tick = 0;
  const end = now() + DURATION * 1000;
  const hardEnd = now() + 3_600_000; // защита: не дольше часа
  const shouldContinue = () =>
    now() < hardEnd && (HOLD === null ? now() < end : !(allReadyAt && now() > allReadyAt + HOLD * 1000));
  liveNow += 1;
  livePeak = Math.max(livePeak, liveNow);
  while (shouldContinue()) {
    phases[index] = "работает";
    const logs = await request(student, "GET", `/runs/${student.run.id}/logs?after_id=${cursor}`);
    if (logs.ok && logs.body.lastId) cursor = logs.body.lastId;
    if (logs.ok) student.logLines += logs.body.logs.length;
    if (tick % 2 === 0) {
      await request(student, "GET", "/projects");
      await request(student, "GET", `/projects/${student.projectId}/runs`);
    }
    if (tick % 20 === 10) {
      const command = await request(student, "POST", `/runs/${student.run.id}/commands`, { json: { command: "echo hello" } });
      if (command.ok) student.commands += 1;
    }
    tick += 1;
    await sleep(1000);
  }
  liveNow -= 1;
}

async function runStudent(index) {
  const student = {
    index,
    email: `stress+${RUN_ID}-${index}@example.com`,
    access: null,
    refresh: null,
    projectId: null,
    run: null,
    refreshes: 0,
    logLines: 0,
    commands: 0,
    timeToRunning: null,
    timeToPreview: null,
    outcome: "ok",
    error: null,
  };
  let startupCounted = false;
  const countStartup = () => {
    if (startupCounted) return;
    startupCounted = true;
    startupDone += 1;
    if (startupDone === STUDENTS) allReadyAt = now();
  };
  try {
    if (RAMP > 0) await sleep((RAMP * 1000 * index) / Math.max(STUDENTS - 1, 1));

    phases[index] = "регистрация";
    const signup = await request(student, "POST", "/signup", { json: { email: student.email, password: "secret123" } });
    if (!signup.ok) throw new Error(`регистрация: ${signup.status} ${JSON.stringify(signup.body)}`);
    student.access = signup.body.accessToken;
    student.refresh = signup.body.refreshToken;

    phases[index] = "загрузка";
    const form = new FormData();
    form.append("name", `Stress ${RUN_ID} #${index}`);
    form.append("archive", await zipBlob(index), "app.zip");
    const created = await request(student, "POST", "/projects", { form });
    if (!created.ok) throw new Error(`загрузка: ${created.status} ${JSON.stringify(created.body)}`);
    student.projectId = created.body.project.id;

    if (!NO_START) {
      const startedAt = now();
      const started = await request(student, "POST", `/projects/${student.projectId}/start`);
      if (!started.ok) throw new Error(`запуск: ${started.status} ${JSON.stringify(started.body)}`);

      const state = await waitForRunning(student, index, startedAt);
      if (state !== "running") throw new Error(`проект не запустился (${state}) ${student.error ?? ""}`.trim());
      student.timeToRunning = now() - startedAt;

      phases[index] = "ждёт приложение";
      if (await waitForPreview(student, startedAt)) student.timeToPreview = now() - startedAt;
      else student.error = "приложение не ответило на предпросмотре";
      countStartup();

      await work(student, index);
    } else {
      countStartup();
      for (let t = 0; t < DURATION; t += 1) {
        await request(student, "GET", "/projects");
        await sleep(1000);
      }
    }
    phases[index] = "готово";
  } catch (error) {
    student.outcome = "ошибка";
    student.error = String(error?.message ?? error);
    phases[index] = "ошибка";
  } finally {
    countStartup(); // даже при ошибке: остальные не должны ждать этого студента вечно
    if (!KEEP && student.projectId) {
      await request(student, "POST", `/projects/${student.projectId}/stop`);
      await request(student, "DELETE", `/projects/${student.projectId}`);
    }
    results.push(student);
  }
}

// ---------- отчёт ----------
function report() {
  console.log("\n================ РЕЗУЛЬТАТ ================");
  const ok = results.filter((s) => s.outcome === "ok" && !s.error);
  console.log(`Студентов: ${STUDENTS}, успешно: ${ok.length}, с ошибками: ${STUDENTS - ok.length}`);

  const running = results.map((s) => s.timeToRunning).filter((v) => v !== null);
  const preview = results.map((s) => s.timeToPreview).filter((v) => v !== null);
  if (running.length) {
    console.log(
      `Время до статуса «работает»:   p50 ${fmt(percentile(running, 50))}, p95 ${fmt(percentile(running, 95))}, максимум ${fmt(Math.max(...running))}`
    );
  }
  if (preview.length) {
    console.log(
      `Время до ответа приложения:    p50 ${fmt(percentile(preview, 50))}, p95 ${fmt(percentile(preview, 95))}, максимум ${fmt(Math.max(...preview))}`
    );
  }
  console.log(`Пик одновременно работающих проектов: ${livePeak} из ${STUDENTS}`);
  console.log(
    `Получено строк логов: ${results.reduce((n, s) => n + s.logLines, 0)}, команд: ${results.reduce((n, s) => n + s.commands, 0)}, обновлений токена: ${results.reduce((n, s) => n + s.refreshes, 0)}`
  );

  console.log("\nЗапросы к API:");
  console.log("  запрос".padEnd(44) + "кол-во".padStart(8) + "ошибок".padStart(8) + "p50".padStart(10) + "p95".padStart(10) + "макс".padStart(10));
  for (const [label, entry] of [...stats.entries()].sort()) {
    console.log(
      `  ${label}`.padEnd(44) +
        String(entry.ms.length).padStart(8) +
        String(entry.errors).padStart(8) +
        fmt(percentile(entry.ms, 50)).padStart(10) +
        fmt(percentile(entry.ms, 95)).padStart(10) +
        fmt(Math.max(...entry.ms)).padStart(10)
    );
  }

  const withErrors = [...stats.entries()].filter(([, entry]) => entry.errors > 0);
  if (withErrors.length) {
    console.log("\nЗапросы с ошибками (код ответа × сколько раз; «сеть» — не удалось соединиться):");
    for (const [label, entry] of withErrors) {
      const codes = [...entry.codes.entries()].map(([code, n]) => `${code} × ${n}`).join(", ");
      console.log(`  ${label}: ${codes}`);
    }
  }

  const failed = results.filter((s) => s.outcome !== "ok" || s.error);
  if (failed.length) {
    console.log("\nПроблемы:");
    const byMessage = new Map();
    for (const s of failed) byMessage.set(s.error, (byMessage.get(s.error) ?? 0) + 1);
    for (const [message, count] of byMessage) console.log(`  ${count} × ${message}`);
  }

  const apiErrors = [...stats.values()].reduce((n, e) => n + e.errors, 0);
  const verdict = failed.length === 0 && apiErrors === 0 ? "ПРОЙДЕН" : "ЕСТЬ ПРОБЛЕМЫ";
  console.log(`\nИтог: ${verdict}`);
  if (!KEEP) console.log(`Тестовые пользователи: email начинается с «stress+${RUN_ID}-» (удалить: см. инструкцию)`);
  return failed.length === 0 && apiErrors === 0 ? 0 : 1;
}

// ---------- запуск ----------
console.log(`Стресс-тест: ${STUDENTS} студентов, сервер ${BASE}, работа после запуска ${DURATION} с, нарастание ${RAMP} с`);
const progress = setInterval(() => {
  const counts = new Map();
  for (const phase of phases) counts.set(phase, (counts.get(phase) ?? 0) + 1);
  const line = [...counts.entries()].map(([phase, n]) => `${phase}: ${n}`).join(" | ");
  console.log(`[${new Date().toLocaleTimeString("ru-RU")}] ${line}`);
}, 5000);

await Promise.all(Array.from({ length: STUDENTS }, (_, index) => runStudent(index)));
clearInterval(progress);
process.exit(report());
