import { type RootState } from "./store";

export const userDataSelector = (state: RootState) => state.user.data;
export const isAuthCheckedSelector = (state: RootState) =>
  state.user.isAuthChecked;
export const isAuthenticatedSelector = (state: RootState) =>
  state.user.isAuthenticated;
export const loginUserErrorSelector = (state: RootState) =>
  state.user.loginUserError;
export const loginUserRequestSelector = (state: RootState) =>
  state.user.loginUserRequest;