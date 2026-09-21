import { useNavigate } from "react-router-dom";
import * as api from "./api";
import { useAuth } from "./AuthContext";

export function DashboardPage() {
  const { user, setUser } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await api.logout();
    setUser(null);
    navigate("/login");
  };

  return (
    <div style={{ padding: 24, fontFamily: "sans-serif" }}>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
        }}
      >
        <h1>Мои проекты</h1>
        <div>
          <span style={{ marginRight: 16 }}>{user?.email}</span>
          <button onClick={handleLogout}>Выйти</button>
        </div>
      </div>
      <p style={{ color: "#888" }}>ля-ля-ля-то-по-ля...</p>
    </div>
  );
}