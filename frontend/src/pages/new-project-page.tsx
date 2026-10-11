import { useEffect, useRef, useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { useDispatch, useSelector } from "../services/store";
import {
  createProject,
  startProject,
  clearCreateError,
} from "../services/slices/projects";
import {
  createProjectErrorSelector,
  createProjectRequestSelector,
} from "../services/selectors";
import { PageHeader } from "../components/page-header";
import { Card } from "../components/card";
import { Button } from "../shared/ui/Button";
import { Input } from "../shared/ui/Input/input";

const MAX_SIZE = 100 * 1024 * 1024;

export function NewProjectPage() {
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const loading = useSelector(createProjectRequestSelector);
  const serverError = useSelector(createProjectErrorSelector);

  const [name, setName] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [localError, setLocalError] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    dispatch(clearCreateError());
  }, [dispatch]);

  const onFileChange = (f: File | null) => {
    setLocalError(null);
    if (!f) return;
    if (!f.name.toLowerCase().endsWith(".zip")) {
      setLocalError("Нужен файл в формате .zip");
      return;
    }
    if (f.size > MAX_SIZE) {
      setLocalError("Архив больше 100 МБ");
      return;
    }
    setFile(f);
    // название подставляется из имени архива, если не введено
    if (!name.trim()) setName(f.name.replace(/\.zip$/i, ""));
  };

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !file) return;

    const created = await dispatch(createProject({ name: name.trim(), archive: file }));
    if (!createProject.fulfilled.match(created)) return;

    // сразу запускаем: распаковка -> сборка -> контейнер
    await dispatch(startProject(created.payload.id));
    navigate(`/projects/${created.payload.id}`, { replace: true });
  };

  const error = localError ?? serverError;

  return (
    <div className="min-h-screen flex flex-col bg-(--color-background)">
      <PageHeader
        rightSlot={
          <Button variant="text" onClick={() => navigate("/")} style={{ padding: "0 24px" }}>
            ← К проектам
          </Button>
        }
      />

      <div className="flex-1 flex items-center justify-center" style={{ padding: 16 }}>
        <Card className="w-full max-w-125" style={{ padding: 40 }}>
          <form onSubmit={onSubmit} className="flex flex-col gap-6">
            <h1 className="font-jost font-medium text-3xl text-(--color-text) text-center">
              Новый проект
            </h1>

            <div className="flex flex-col gap-2">
              <span className="text-sm text-(--color-caption)">
                ZIP-архив с Rails-проектом
              </span>
              <input
                ref={fileRef}
                type="file"
                accept=".zip,application/zip"
                className="hidden"
                onChange={(e) => onFileChange(e.target.files?.[0] ?? null)}
              />
              <button
                type="button"
                onClick={() => fileRef.current?.click()}
                className="w-full rounded-xl border-2 border-dashed border-(--color-border) hover:border-(--color-accent) transition-colors cursor-pointer text-(--color-caption)"
                style={{ padding: "28px 16px" }}
              >
                {file
                  ? `${file.name} (${(file.size / 1024 / 1024).toFixed(1)} МБ)`
                  : "Нажмите, чтобы выбрать .zip (до 100 МБ)"}
              </button>
              <span className="text-xs text-(--color-caption)">
                В архиве должен быть Gemfile. Проект запускается в Docker в режиме development на порту 3000 (свой Dockerfile платформа создаёт сама).
              </span>
            </div>

            <Input
              label="Название"
              placeholder="Подставится из имени архива"
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={100}
            />

            {error && (
              <p className="text-sm text-(--color-error)" role="alert">
                {error}
              </p>
            )}

            <Button
              type="submit"
              variant="primary"
              className="w-full"
              disabled={loading || !name.trim() || !file}
            >
              {loading ? "Загрузка…" : "Загрузить и запустить"}
            </Button>
          </form>
        </Card>
      </div>
    </div>
  );
}
