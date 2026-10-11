import { useEffect, useState } from "react";
import { Navigate, useNavigate, useParams } from "react-router-dom";
import { useDispatch, useSelector } from "../services/store";
import {
  fetchProjects,
  startProject,
  stopProject,
  deleteProject,
  clearActionError,
} from "../services/slices/projects";
import {
  actionErrorSelector,
  projectByIdSelector,
  projectsLoadedSelector,
} from "../services/selectors";
import { getRunsApi } from "../services/api";
import type { Run } from "../services/types";
import { formatDateTime, formatDuration } from "../services/utils/format";
import { PageHeader } from "../components/page-header";
import { Card } from "../components/card";
import { StatusBadge, RunStatusBadge } from "../components/status-badge";
import { AppPreview } from "../components/app-preview";
import { LogViewer } from "../components/log-viewer";
import { CommandConsole } from "../components/command-console";
import { Button } from "../shared/ui/Button";

const cell = { padding: "10px 12px", textAlign: "left" as const };
const btn = { padding: "0 24px" };

function runDuration(run: Run): string {
  if (!run.startedAt) return "—";
  const end = run.finishedAt ? new Date(run.finishedAt).getTime() : Date.now();
  return formatDuration((end - new Date(run.startedAt).getTime()) / 1000);
}

export function ProjectPage() {
  const { id } = useParams();
  const projectId = Number(id);
  const dispatch = useDispatch();
  const navigate = useNavigate();

  const project = useSelector((s) => projectByIdSelector(s, projectId));
  const loaded = useSelector(projectsLoadedSelector);
  const actionError = useSelector(actionErrorSelector);

  const [runs, setRuns] = useState<Run[]>([]);
  const [selectedRunId, setSelectedRunId] = useState<number | null>(null);

  // Проект и список запусков обновляются каждые 2 секунды
  useEffect(() => {
    dispatch(clearActionError());
    let stopped = false;
    const load = async () => {
      dispatch(fetchProjects());
      try {
        const data = await getRunsApi(projectId);
        if (!stopped) setRuns(data.runs);
      } catch {
        /* следующий тик попробует снова */
      }
    };
    load();
    const timer = window.setInterval(load, 2000);
    return () => {
      stopped = true;
      window.clearInterval(timer);
    };
  }, [dispatch, projectId]);

  // Новый активный запуск — сразу показываем его
  useEffect(() => {
    if (project?.activeRunId) setSelectedRunId(project.activeRunId);
  }, [project?.activeRunId]);

  // Иначе — последний запуск
  useEffect(() => {
    if (selectedRunId == null && runs.length > 0) setSelectedRunId(runs[0].id);
  }, [runs, selectedRunId]);

  if (!loaded) return <p style={{ padding: 24 }}>Загрузка...</p>;
  if (!project) return <Navigate to="/" replace />;

  const selectedRun = runs.find((r) => r.id === selectedRunId) ?? null;
  const runActive =
    selectedRun?.status === "pending" || selectedRun?.status === "running";
  const isRunning = project.status === "running";

  const handleStart = async () => {
    const result = await dispatch(startProject(project.id));
    if (startProject.fulfilled.match(result)) {
      setRuns((prev) => [result.payload, ...prev.filter((r) => r.id !== result.payload.id)]);
      setSelectedRunId(result.payload.id);
    }
  };

  const handleToggle = async () => {
    if (isRunning) await dispatch(stopProject(project.id));
    else await handleStart();
  };

  const handleDelete = async () => {
    if (!window.confirm(`Удалить проект «${project.name}» вместе с историей запусков?`)) return;
    const result = await dispatch(deleteProject(project.id));
    if (deleteProject.fulfilled.match(result)) navigate("/", { replace: true });
  };

  return (
    <div className="min-h-screen flex flex-col bg-(--color-background)">
      <PageHeader
        rightSlot={
          <Button variant="text" onClick={() => navigate("/")} style={btn}>
            ← К проектам
          </Button>
        }
      />

      <div className="flex-1 flex flex-col gap-4" style={{ padding: 16 }}>
        {/* Панель проекта */}
        <Card
          className="flex items-center justify-between gap-4 flex-wrap"
          style={{ padding: "12px 20px" }}
        >
          <div className="flex items-center gap-4 flex-wrap">
            <h1 className="font-jost font-medium text-2xl text-(--color-text)">
              {project.name}
            </h1>
            <StatusBadge status={project.status} />
            {actionError && (
              <span className="text-sm text-(--color-error)" role="alert">
                {actionError}
              </span>
            )}
          </div>
          <div className="flex gap-3">
            <Button variant="primary" onClick={handleToggle} style={btn}>
              {isRunning ? "Остановить" : "Запустить"}
            </Button>
            <Button variant="secondary" onClick={handleDelete} style={btn}>
              Удалить
            </Button>
          </div>
        </Card>

        {/* Рабочая область: приложение слева (почти на весь экран), логи справа */}
        <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_380px] gap-4 lg:h-[calc(100vh-215px)] lg:min-h-130">
          <AppPreview run={selectedRun} onStart={handleStart} />
          {selectedRun ? (
            <LogViewer key={selectedRun.id} runId={selectedRun.id} active={runActive} />
          ) : (
            <Card className="flex items-center justify-center text-(--color-caption)">
              Логи появятся после запуска
            </Card>
          )}
        </div>

        {/* Ниже — консоль и история запусков */}
        {selectedRun && (
          <CommandConsole
            runId={selectedRun.id}
            canRun={selectedRun.status === "running"}
          />
        )}

        <Card className="flex flex-col gap-4">
          <h3 className="font-jost font-medium text-xl text-(--color-text)">
            История запусков
          </h3>
          {runs.length === 0 ? (
            <p className="text-(--color-caption)">Проект ещё не запускался</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm" style={{ borderCollapse: "collapse" }}>
                <thead>
                  <tr
                    className="text-(--color-caption)"
                    style={{ borderBottom: "1px solid var(--color-border)" }}
                  >
                    <th style={cell}>#</th>
                    <th style={cell}>Статус</th>
                    <th style={cell}>Начало</th>
                    <th style={cell}>Длительность</th>
                    <th style={cell}>Код выхода</th>
                  </tr>
                </thead>
                <tbody>
                  {runs.map((run) => (
                    <tr
                      key={run.id}
                      onClick={() => setSelectedRunId(run.id)}
                      className="cursor-pointer hover:bg-(--color-input) text-(--color-text)"
                      style={{
                        borderBottom: "1px solid var(--color-border)",
                        background: run.id === selectedRunId ? "var(--color-input)" : undefined,
                      }}
                    >
                      <td style={cell}>{run.id}</td>
                      <td style={cell}>
                        <RunStatusBadge status={run.status} />
                      </td>
                      <td style={cell}>{formatDateTime(run.startedAt ?? run.createdAt)}</td>
                      <td style={cell}>{runDuration(run)}</td>
                      <td style={cell}>{run.exitCode ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}
