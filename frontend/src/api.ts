import axios from "axios";

const client = axios.create({
  baseURL: "/api",
  withCredentials: true, 
});

export const register = (email: string, password: string) =>
  client.post("/signup", { email, password }).then((r) => r.data);

export const login = (email: string, password: string) =>
  client.post("/login", { email, password }).then((r) => r.data);

export const logout = () => client.delete("/logout").then((r) => r.data);

export const me = () =>
  client
    .get("/me")
    .then((r) => r.data)
    .catch(() => ({ error: "Не авторизован" }));