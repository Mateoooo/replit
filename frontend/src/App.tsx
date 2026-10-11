import { useEffect } from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { Provider } from "react-redux";
import { store, useDispatch } from "./services/store";
import { checkUserAuth, userLogout } from "./services/slices/user";
import { ProtectedRoute } from "./components/protected-route";
import { LoginPage } from "./pages/login-page";
import { RegisterPage } from "./pages/register-page";
import { DashboardPage } from "./pages/dashboard-page";
import { NewProjectPage } from "./pages/new-project-page";
import { ProjectPage } from "./pages/project-page";

function AppRoutes() {
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(checkUserAuth());
  }, [dispatch]);

  // api.ts шлёт это событие, когда refresh-токен истёк (30 дней) или отозван
  useEffect(() => {
    const onExpired = () => dispatch(userLogout());
    window.addEventListener("auth:expired", onExpired);
    return () => window.removeEventListener("auth:expired", onExpired);
  }, [dispatch]);

  return (
    <Routes>
      <Route
        path="/login"
        element={
          <ProtectedRoute onlyUnAuth>
            <LoginPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/register"
        element={
          <ProtectedRoute onlyUnAuth>
            <RegisterPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <DashboardPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/projects/new"
        element={
          <ProtectedRoute>
            <NewProjectPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/projects/:id"
        element={
          <ProtectedRoute>
            <ProjectPage />
          </ProtectedRoute>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <Provider store={store}>
      <BrowserRouter>
        <AppRoutes />
      </BrowserRouter>
    </Provider>
  );
}
