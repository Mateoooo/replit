import { Navigate, useLocation } from "react-router-dom";
import {
  isAuthCheckedSelector,
  userDataSelector,
} from "../services/selectors";
import { useSelector } from "../services/store";

type ProtectedRouteProps = {
  onlyUnAuth?: boolean;
  children: React.ReactElement;
};

export function ProtectedRoute({ onlyUnAuth, children }: ProtectedRouteProps) {
  const isAuthChecked = useSelector(isAuthCheckedSelector);
  const user = useSelector(userDataSelector);
  const location = useLocation();

  if (!isAuthChecked) {
    return <p style={{ padding: 24 }}>Загрузка...</p>;
  }

  if (!onlyUnAuth && !user) {
    return <Navigate replace to="/login" state={{ from: location }} />;
  }

  if (onlyUnAuth && user) {
    const from = location.state?.from || { pathname: "/" };
    return <Navigate replace to={from} />;
  }

  return children;
}