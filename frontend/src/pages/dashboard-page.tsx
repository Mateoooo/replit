import { useNavigate } from "react-router-dom";
import { useDispatch, useSelector } from "../services/store";
import { logoutUser } from "../services/slices/user";
import { userDataSelector } from "../services/selectors";
import { PageHeader } from "../components/page-header";
import { Button } from "../shared/ui/Button";
import { Illustration } from "../components/illustration";

// Типы — заведём здесь пока, потом вынесем в services/slices/projects
type ProjectStatus = "running" | "stopped" | "failed" | "created";

type Project = {
  id: number;
  name: string;
  status: ProjectStatus;
  lastRunAt: string | null;
  createdAt: string;
};

// Мок-данные — потом заменим на реальный запрос к /api/projects
const MOCK_PROJECTS: Project[] = [
  {
    id: 1,
    name: "Rails Quest",
    status: "running",
    lastRunAt: "2 минуты назад",
    createdAt: "12.09.2026",
  },
  {
    id: 2,
    name: "Blog API",
    status: "stopped",
    lastRunAt: "вчера, 18:30",
    createdAt: "10.09.2026",
  },
  {
    id: 3,
    name: "Todo List",
    status: "failed",
    lastRunAt: "3 дня назад",
    createdAt: "08.09.2026",
  },
];

// Конфиг для бейджа статуса
const STATUS_CONFIG: Record<
  ProjectStatus,
  { label: string; dot: string; text: string; bg: string }
> = {
  running: {
    label: "Запущен",
    dot: "#22c55e",
    text: "#166534",
    bg: "#dcfce7",
  },
  stopped: {
    label: "Остановлен",
    dot: "#94a3b8",
    text: "#475569",
    bg: "#f1f5f9",
  },
  failed: {
    label: "Ошибка",
    dot: "#ef4444",
    text: "#991b1b",
    bg: "#fee2e2",
  },
  created: {
    label: "Создан",
    dot: "#3b82f6",
    text: "#1e40af",
    bg: "#dbeafe",
  },
};

function StatusBadge({ status }: { status: ProjectStatus }) {
  const config = STATUS_CONFIG[status];
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "6px",
        padding: "4px 10px",
        borderRadius: "999px",
        fontSize: "12px",
        fontWeight: 500,
        backgroundColor: config.bg,
        color: config.text,
      }}
    >
      <span
        style={{
          width: "8px",
          height: "8px",
          borderRadius: "50%",
          backgroundColor: config.dot,
        }}
      />
      {config.label}
    </span>
  );
}

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
    <div className="bg-(--color-card) rounded-xl shadow-sm p-6 flex flex-col gap-4 min-h-62.5 max-w-95 justify-center"
    style={{ padding: "15px" }}>
      {/* Название + статус */}
      <div className="flex items-start justify-between gap-4">
        <h3 className="font-jost font-medium text-xl text-(--color-text) wrap-break-word">
          {project.name}
        </h3>
        <StatusBadge status={project.status} />
      </div>

      {/* Метаданные */}
      <div className="text-sm text-(--color-caption) flex flex-col gap-1">
        <span>Последний запуск: {project.lastRunAt ?? "—"}</span>
        <span>Создан: {project.createdAt}</span>
      </div>

      {/* Кнопки — прижаты к низу карточки */}
      <div className="mt-auto flex gap-3">
        <Button
          variant="secondary"
          className="flex-1"
          onClick={onOpen}
        >
          Открыть
        </Button>
        <Button
          variant="primary"
          className="flex-1"
          onClick={onToggleRun}
        >
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

  // Пока — мок. Потом заменим на useSelector из среза projects
  const projects = MOCK_PROJECTS;

  const handleLogout = () => {
    dispatch(logoutUser());
  };

  const handleCreate = () => {
    navigate("/projects/new");
  };

  const handleOpen = (id: number) => {
    navigate(`/projects/${id}`);
  };

  const handleToggleRun = (id: number) => {
    // TODO: dispatch(runProject(id)) или stopProject(id)
    console.log("toggle run for project", id);
  };

  return (
    <div className="min-h-screen flex flex-col bg-(--color-background)">
      {/* Шапка с кнопкой «Выйти» */}
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
        <div className="w-full max-w-[1700px] mx-auto">
          {/* Пустое состояние или сетка карточек */}
          {projects.length === 0 ? (
            <div className="bg-(--color-card) rounded-xl shadow-sm p-10 flex flex-col items-center text-center">
              <Illustration />
              <h2 className="text-h2 font-jost text-(--color-text) mt-6">
                Проектов пока нет
              </h2>
              <p className="mt-2 text-(--color-caption) max-w-100">
                Загрузите ZIP с Rails-проектом, и мы запустим его в
                изолированном контейнере
              </p>
              <Button
                variant="primary"
                className="mt-8"
                onClick={handleCreate}
              >
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
                  onToggleRun={() => handleToggleRun(project.id)}
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