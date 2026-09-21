import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import * as api from "./api";
import { useAuth } from "./AuthContext";

export function RegisterPage() {
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
      const user = await api.register(email, password);
      setUser(user);
      navigate("/");
    } catch (err: any) {
      const errors = err.response?.data?.errors;
      setError(Array.isArray(errors) ? errors.join(", ") : "Ошибка регистрации");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: 320, margin: "80px auto", fontFamily: "sans-serif" }}>
      <h1>Регистрация</h1>
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
            minLength={6}
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
          {loading ? "Создаём..." : "Зарегистрироваться"}
        </button>
      </form>
      <p style={{ marginTop: 12 }}>
        Уже есть аккаунт? <Link to="/login">Войти</Link>
      </p>
    </div>
  );
}