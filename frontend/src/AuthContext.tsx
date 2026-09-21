import { createContext, useContext, useEffect, useState } from "react";
import * as api from "./api";

type User = { id: number; email: string } | null;

interface AuthContextValue {
  user: User;
  setUser: (u: User) => void;
  loading: boolean;
}

const AuthContext = createContext<AuthContextValue>({
  user: null,
  setUser: () => {},
  loading: true,
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User>(null);
  const [loading, setLoading] = useState(true);

  // При старте приложения спрашиваем у бэка: "кто я?"
  useEffect(() => {
    api
      .me()
      .then((data) => {
        if (data?.id) setUser(data);
        else setUser(null);
      })
      .catch(() => setUser(null))
      .finally(() => setLoading(false));
  }, []);

  return (
    <AuthContext.Provider value={{ user, setUser, loading }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);