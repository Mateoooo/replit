import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import * as api from "./api";
import { useAuth } from "./AuthContext";

export function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { setUser } = useAuth();
  const navigate = useNavigate();

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const user = await api.login(email, password);
      setUser(user);
      navigate("/");
    } catch (err: any) {
      setError(err.response?.data?.error ?? "Ошибка входа");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: 320, margin: "80px auto", fontFamily: "sans-serif" }}>
      <h1>Вход</h1>
      <form onSubmit={submit}>
        <div style={{ marginBottom: 12 }}>
          <label>Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            style={{ width: "100%", padding: 8, marginTop: 4 }}
          />
        </div>
        <div style={{ marginBottom: 12 }}>
          <label>Пароль</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            style={{ width: "100%", padding: 8, marginTop: 4 }}
          />
        </div>
        {error && <p style={{ color: "red" }}>{error}</p>}
        <button
          type="submit"
          disabled={loading}
          style={{ width: "100%", padding: 10, cursor: "pointer" }}
        >
          {loading ? "Входим..." : "Войти"}
        </button>
      </form>
      <p style={{ marginTop: 12 }}>
        Нет аккаунта? <Link to="/register">Регистрация</Link>
      </p>
    </div>
  );
}