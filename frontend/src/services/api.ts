import { getCookie, setCookie, deleteCookie } from "./utils/cookie";
import type {
  Project,
  Run,
  LogsResponse,
  CommandExecution,
} from "./types";

export const API_URL: string =
  import.meta.env.VITE_API_URL ?? "http://localhost:3000";

function checkResponse<T>(res: Response): Promise<T> {
  return res.ok
    ? res.json()
    : res
        .json()
        .catch(() => ({}))
        .then((err) => Promise.reject({ ...err, statusCode: res.status }));
}

// Заголовки теперь ОБЪЕДИНЯЮТСЯ (раньше options.headers полностью затирал content-type).
// Для FormData content-type не ставим — браузер сам добавит boundary.
async function request<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const headers = new Headers(options.headers);
  if (!(options.body instanceof FormData) && !headers.has("content-type")) {
    headers.set("content-type", "application/json");
  }
  const res = await fetch(`${API_URL}/${endpoint}`, { ...options, headers });
  return checkResponse<T>(res);
}

export function errorMessage(err: any, fallback: string): string {
  if (Array.isArray(err?.errors)) return err.errors.join(", ");
  return err?.error ?? fallback;
}

async function refreshAccessToken(): Promise<string> {
  const token = localStorage.getItem("refreshToken");
  if (!token) return Promise.reject({ statusCode: 401, error: "Нет сессии" });

  const data = await request<{ accessToken: string }>("auth/token", {
    method: "POST",
    body: JSON.stringify({ token }),
  });
  setCookie("accessToken", data.accessToken);
  return data.accessToken;
}

// Запрос с авторизацией: токен подставляется автоматически,
// при 401 обновляем access-токен по refresh и повторяем запрос.
export async function fetchWithRefresh<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const withAuth = (token?: string): RequestInit => {
    const headers = new Headers(options.headers);
    if (token) headers.set("authorization", `Bearer ${token}`);
    return { ...options, headers };
  };

  try {
    return await request<T>(endpoint, withAuth(getCookie("accessToken")));
  } catch (error: any) {
    if (error.statusCode !== 401) return Promise.reject(error);

    try {
      const token = await refreshAccessToken();
      return await request<T>(endpoint, withAuth(token));
    } catch (e: any) {
      if (e.statusCode === 401) {
        // refresh-токен истёк (30 дней) или отозван — сессия закончена
        localStorage.removeItem("refreshToken");
        deleteCookie("accessToken");
        window.dispatchEvent(new Event("auth:expired"));
      }
      return Promise.reject(e);
    }
  }
}

// ---------- Авторизация ----------
type AuthResponse = { user: any; accessToken: string; refreshToken: string };

export const registerApi = (email: string, password: string) =>
  request<AuthResponse>("signup", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });

export const loginApi = (email: string, password: string) =>
  request<AuthResponse>("login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });

export const logoutApi = (refreshToken: string) =>
  request<{ ok: boolean }>("logout", {
    method: "DELETE",
    body: JSON.stringify({ token: refreshToken }),
  });

export const getUserApi = () => fetchWithRefresh<{ user: any }>("me");

// ---------- Проекты ----------
export const getProjectsApi = () =>
  fetchWithRefresh<{ projects: Project[] }>("projects");

export const createProjectApi = (name: string, archive: File) => {
  const form = new FormData();
  form.append("name", name);
  form.append("archive", archive);
  return fetchWithRefresh<{ project: Project }>("projects", {
    method: "POST",
    body: form,
  });
};

export const deleteProjectApi = (id: number) =>
  fetchWithRefresh<{ ok: boolean }>(`projects/${id}`, { method: "DELETE" });

export const startProjectApi = (id: number) =>
  fetchWithRefresh<{ run: Run }>(`projects/${id}/start`, { method: "POST" });

export const stopProjectApi = (id: number) =>
  fetchWithRefresh<{ run: Run }>(`projects/${id}/stop`, { method: "POST" });

// ---------- Запуски, логи, команды ----------
export const getRunsApi = (projectId: number) =>
  fetchWithRefresh<{ runs: Run[] }>(`projects/${projectId}/runs`);

export const getLogsApi = (runId: number, afterId: number) =>
  fetchWithRefresh<LogsResponse>(`runs/${runId}/logs?after_id=${afterId}`);

export const getCommandsApi = (runId: number) =>
  fetchWithRefresh<{ commands: CommandExecution[] }>(`runs/${runId}/commands`);

export const runCommandApi = (runId: number, command: string) =>
  fetchWithRefresh<{ command: CommandExecution }>(`runs/${runId}/commands`, {
    method: "POST",
    body: JSON.stringify({ command }),
  });
