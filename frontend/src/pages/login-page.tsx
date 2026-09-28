import { useState, type ChangeEvent, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { useDispatch, useSelector } from "../services/store";
import { loginUser } from "../services/slices/user";
import {
  loginUserErrorSelector,
  loginUserRequestSelector,
} from "../services/selectors";
import { Button } from "../shared/ui/Button";
import { Input } from "../shared/ui/Input/input";
import { PasswordToggle } from "../shared/ui/password-toggle";
import { PageHeader } from "../components/page-header";
import { Illustration } from "../components/illustration";

export function LoginPage() {
  const dispatch = useDispatch();
  const error = useSelector(loginUserErrorSelector);
  const loading = useSelector(loginUserRequestSelector);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (!email || !password) return;
    dispatch(loginUser({ email, password }));
  };

  return (
    <div className="min-h-screen flex flex-col bg-(--color-background)">
      <PageHeader />

      <div className="flex-1 flex items-center justify-center p-4 sm:p-6">
        <div className="flex flex-col lg:flex-row gap-6 w-full max-w-284">
          {/* Карточка с формой */}
          <div className="w-full lg:flex-1 min-h-175 bg-(--color-card) rounded-xl shadow-sm p-6 sm:p-10 lg:p-15 flex flex-col justify-center items-center mb-8 ">
            <form onSubmit={onSubmit} className="w-full max-w-100 min-h-125 flex flex-col justify-center gap-5">
              <h1 className="text-h1 font-jost text-(--color-text) mb-8 mt-8 text-center">
                Вход
              </h1>

              <div className="mb-7">
                <Input
                  type="email"
                  label="Email"
                  placeholder="Введите email"
                  value={email}
                  onChange={(e: ChangeEvent<HTMLInputElement>) =>
                    setEmail(e.target.value)
                  }
                  required
                />
              </div>

              <div className="mb-9">
                <Input
                  type={showPassword ? "text" : "password"}
                  label="Пароль"
                  placeholder="Введите пароль"
                  value={password}
                  onChange={(e: ChangeEvent<HTMLInputElement>) =>
                    setPassword(e.target.value)
                  }
                  required
                  rightSlot={
                    <PasswordToggle
                      visible={showPassword}
                      onToggle={() => setShowPassword(!showPassword)}
                    />
                  }
                />
              </div>

              {error && (
                <p
                  className="mt-2 text-sm text-(--color-error)"
                  role="alert"
                >
                  {error}
                </p>
              )}

              <Button
                type="submit"
                variant="primary"
                className="w-full mt-17"
                disabled={loading}
              >
                {loading ? "Вход..." : "Войти"}
              </Button>

              <p className="text-center mt-6 text-sm text-(--color-caption)">
                Нет аккаунта?{" "}
                <Link
                  to="/register"
                  className="text-(--color-text-link) hover:underline"
                >
                  Зарегистрироваться
                </Link>
              </p>
            </form>
          </div>

          {/* Карточка с приветствием */}
          <div className="w-full lg:flex-1 min-h-100 bg-(--color-card) rounded-xl shadow-sm p-6 sm:p-10 lg:p-15 flex flex-col items-center justify-center">
            <Illustration />
            <div className="w-full max-w-100 mt-8 text-center">
              <p className="text-h2 font-jost text-(--color-text)">
                Добро пожаловать в Replit!
              </p>
              <p className="mt-3 text-base text-(--color-caption)">
                Запускайте Ruby on Rails проекты в изолированных
                Docker-контейнерах прямо из браузера
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}