import { getCookie, setCookie } from "./utils/cookie";

const URL = "http://localhost:3000";

function checkResponse<T>(res: Response): Promise<T> {
  return res.ok
    ? res.json()
    : res
        .json()
        .then((err) =>
          Promise.reject({ ...err, statusCode: res.status })
        );
}

async function request<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const res = await fetch(`${URL}/${endpoint}`, {
    headers: { "content-type": "application/json" },
    ...options,
  });
  return await checkResponse<T>(res);
}

// Обновление access-токена по refresh
function refreshToken(): Promise<{ accessToken: string }> {
  return request<{ accessToken: string }>("auth/token", {
    method: "POST",
    body: JSON.stringify({ token: localStorage.getItem("refreshToken") }),
  });
}

// Обёртка: если запрос упал с 401 — обновляем токен и пробуем снова
export async function fetchWithRefresh<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  try {
    return await request<T>(endpoint, options);
  } catch (error: any) {
    if (error.statusCode === 401 || error.statusCode === 403) {
      const refreshData = await refreshToken();
      if (!refreshData.accessToken) {
        return Promise.reject(refreshData);
      }

      setCookie("accessToken", refreshData.accessToken);

      return await request<T>(endpoint, {
        ...options,
        headers: {
          ...options.headers,
          authorization: `Bearer ${getCookie("accessToken")}`,
        },
      });
    }
    return Promise.reject(error);
  }
}

// API-методы
export const registerApi = (email: string, password: string) =>
  request<{ user: any; accessToken: string; refreshToken: string }>("signup", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });

export const loginApi = (email: string, password: string) =>
  request<{ user: any; accessToken: string; refreshToken: string }>("login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });

export const logoutApi = (refreshToken: string) =>
  request<{ ok: boolean }>("logout", {
    method: "DELETE",
    body: JSON.stringify({ token: refreshToken }),
  });

export const getUserApi = () =>
  fetchWithRefresh<{ user: any }>("me", {
    method: "GET",
    headers: { authorization: `Bearer ${getCookie("accessToken")}` },
  });