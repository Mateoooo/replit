import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useDispatch, useSelector } from "../services/store";
import { logoutUser } from "../services/slices/user";
import {
  fetchProjects,
  startProject,
  stopProject,
  clearActionError,
} from "../services/slices/projects";
import {
  actionErrorSelector,
  projectsErrorSelector,
  projectsLoadedSelector,
  projectsSelector,
  userDataSelector,
} from "../services/selectors";
import type { Project } from "../services/types";
import { formatDateTime } from "../services/utils/format";
import { PageHeader } from "../components/page-header";
import { StatusBadge } from "../components/status-badge";
import { Button } from "../shared/ui/Button";
import { Illustration } from "../components/illustration";

function ProjectCard({
  project,
  onOpen,
  onToggleRun,
}: {
  project: Project;
  onOpen: () => void;
  onToggleRun: () => void;
}) {
  const isRunning = project.status === "running";

  return (
    <div
      className="bg-(--color-card) rounded-xl shadow-sm p-6 flex flex-col gap-4 min-h-62.5 max-w-95 justify-center"
      style={{ padding: "15px" }}
    >
      <div className="flex items-start justify-between gap-4">
        <h3 className="font-jost font-medium text-xl text-(--color-text) wrap-break-word">
          {project.name}
        </h3>
        <StatusBadge status={project.status} />
      </div>

      <div className="text-sm text-(--color-caption) flex flex-col gap-1">
        <span>Последний запуск: {formatDateTime(project.lastRunAt)}</span>
        <span>Создан: {formatDateTime(project.createdAt)}</span>
      </div>

      <div className="mt-auto flex gap-3">
        <Button variant="secondary" className="flex-1" onClick={onOpen}>
          Открыть
        </Button>
        <Button variant="primary" className="flex-1" onClick={onToggleRun}>
          {isRunning ? "Остановить" : "Запустить"}
        </Button>
      </div>
    </div>
  );
}

function CreateProjectCard({ onClick }: { onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="bg-(--color-card) rounded-xl shadow-sm p-6 min-h-62.5 flex flex-col items-center justify-center gap-4 cursor-pointer transition-all hover:shadow-md border-2 border-dashed border-(--color-border) hover:border-(--color-accent) group"
    >
      <div className="w-16 h-16 rounded-full flex items-center justify-center transition-colors bg-(--color-input) group-hover:bg-(--color-accent)">
        <svg
          width="32"
          height="32"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="text-(--color-accent) group-hover:text-(--color-text-on-accent) transition-colors"
        >
          <line x1="12" y1="5" x2="12" y2="19" />
          <line x1="5" y1="12" x2="19" y2="12" />
        </svg>
      </div>
      <span className="font-jost font-medium text-lg text-(--color-text)">
        Создать проект
      </span>
      <span className="text-sm text-(--color-caption) text-center max-w-50">
        Загрузите ZIP с Rails-проектом
      </span>
    </button>
  );
}

export function DashboardPage() {
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const user = useSelector(userDataSelector);
  const projects = useSelector(projectsSelector);
  const loaded = useSelector(projectsLoadedSelector);
  const loadError = useSelector(projectsErrorSelector);
  const actionError = useSelector(actionErrorSelector);

  // Загружаем и обновляем список каждые 5 секунд (статусы меняются сами)
  useEffect(() => {
    dispatch(clearActionError());
    dispatch(fetchProjects());
    const timer = window.setInterval(() => dispatch(fetchProjects()), 5000);
    return () => window.clearInterval(timer);
  }, [dispatch]);

  const handleLogout = () => dispatch(logoutUser());
  const handleCreate = () => navigate("/projects/new");
  const handleOpen = (id: number) => navigate(`/projects/${id}`);
  const handleToggleRun = (project: Project) => {
    dispatch(
      project.status === "running"
        ? stopProject(project.id)
        : startProject(project.id)
    );
  };

  return (
    <div className="min-h-screen flex flex-col bg-(--color-background)">
      <PageHeader
        rightSlot={
          <div className="flex items-center gap-4">
            <span className="text-sm text-(--color-caption) hidden sm:inline">
              {user?.email}
            </span>
            <Button variant="text" onClick={handleLogout}>
              Выйти
            </Button>
          </div>
        }
      />

      <div className="flex-1 px-4 pt-4 pb-8 sm:px-6" style={{ padding: "16px" }}>
        <div className="w-full max-w-[1700px] mx-auto flex flex-col gap-4">
          {(actionError || loadError) && (
            <p className="text-sm text-(--color-error)" role="alert">
              {actionError ?? loadError}
            </p>
          )}

          {!loaded ? (
            <p className="text-(--color-caption)">Загрузка проектов...</p>
          ) : projects.length === 0 ? (
            <div className="bg-(--color-card) rounded-xl shadow-sm p-10 flex flex-col items-center text-center" style={{ padding: 40 }}>
              <Illustration />
              <h2 className="text-h2 font-jost text-(--color-text) mt-6">
                Проектов пока нет
              </h2>
              <p className="mt-2 text-(--color-caption) max-w-100">
                Загрузите ZIP с Rails-проектом, и мы запустим его в
                изолированном контейнере
              </p>
              <Button variant="primary" className="mt-8" onClick={handleCreate}>
                + Создать первый проект
              </Button>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              {projects.map((project) => (
                <ProjectCard
                  key={project.id}
                  project={project}
                  onOpen={() => handleOpen(project.id)}
                  onToggleRun={() => handleToggleRun(project)}
                />
              ))}
              <CreateProjectCard onClick={handleCreate} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
