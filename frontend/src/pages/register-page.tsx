import { useState, type ChangeEvent, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { useDispatch, useSelector } from "../services/store";
import { registerUser } from "../services/slices/user";
import {
  loginUserErrorSelector,
  loginUserRequestSelector,
} from "../services/selectors";
import { Button } from "../shared/ui/Button";
import { Input } from "../shared/ui/Input/input";
import { PasswordToggle } from "../shared/ui/password-toggle";
import { PageHeader } from "../components/page-header";
import { Illustration } from "../components/illustration";

export function RegisterPage() {
  const dispatch = useDispatch();
  const error = useSelector(loginUserErrorSelector);
  const loading = useSelector(loginUserRequestSelector);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [localError, setLocalError] = useState<string | null>(null);

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    setLocalError(null);

    if (password.length < 6) {
      setLocalError("Пароль должен быть не короче 6 символов");
      return;
    }
    if (password !== confirm) {
      setLocalError("Пароли не совпадают");
      return;
    }
    dispatch(registerUser({ email, password }));
  };

  const displayError = localError || error;

  return (
    <div className="min-h-screen flex flex-col bg-(--color-background)">
      <PageHeader />

      <div className="flex-1 flex items-center justify-center p-4 sm:p-6">
        <div className="flex flex-col lg:flex-row gap-6 w-full max-w-284">
          {/* Карточка с формой */}
          <div className="w-full lg:flex-1 min-h-175 bg-(--color-card) rounded-xl shadow-sm p-6 sm:p-10 lg:p-15 flex flex-col justify-center items-center">
            <form onSubmit={onSubmit} className="w-full max-w-100 min-h-125 flex flex-col justify-center gap-5">
              <h1 className="text-h1 font-jost text-(--color-text) mb-8 text-center">
                Регистрация
              </h1>

              <div className="mb-6">
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

              <div className="mb-6">
                <Input
                  type={showPassword ? "text" : "password"}
                  label="Пароль"
                  placeholder="Минимум 6 символов"
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

              <div className="mb-6">
                <Input
                  type={showPassword ? "text" : "password"}
                  label="Повторите пароль"
                  placeholder="Повторите пароль"
                  value={confirm}
                  onChange={(e: ChangeEvent<HTMLInputElement>) =>
                    setConfirm(e.target.value)
                  }
                  required
                />
              </div>

              {displayError && (
                <p
                  className="mt-2 text-sm text-(--color-error)"
                  role="alert"
                >
                  {displayError}
                </p>
              )}

              <Button
                type="submit"
                variant="primary"
                className="w-full mt-10"
                disabled={loading}
              >
                {loading ? "Создаём..." : "Зарегистрироваться"}
              </Button>

              <p className="text-center mt-6 text-sm text-(--color-caption)">
                Уже есть аккаунт?{" "}
                <Link
                  to="/login"
                  className="text-(--color-text-link) hover:underline"
                >
                  Войти
                </Link>
              </p>
            </form>
          </div>

          {/* Карточка с приветствием */}
          <div className="w-full lg:flex-1 min-h-100 bg-(--color-card) rounded-xl shadow-sm p-6 sm:p-10 lg:p-15 flex flex-col items-center justify-center">
            <Illustration />
            <div className="w-full max-w-100 mt-8 text-center">
              <p className="text-h2 font-jost text-(--color-text)">
                Начните прямо сейчас
              </p>
              <p className="mt-3 text-base text-(--color-caption)">
                Создайте аккаунт и запускайте
                свои Rails-проекты в облаке
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}