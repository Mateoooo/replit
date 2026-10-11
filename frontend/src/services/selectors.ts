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

// projects
export const projectsSelector = (state: RootState) => state.projects.items;
export const projectsLoadedSelector = (state: RootState) =>
  state.projects.loaded;
export const projectsErrorSelector = (state: RootState) => state.projects.error;
export const projectByIdSelector = (state: RootState, id: number) =>
  state.projects.items.find((p) => p.id === id);
export const createProjectRequestSelector = (state: RootState) =>
  state.projects.createRequest;
export const createProjectErrorSelector = (state: RootState) =>
  state.projects.createError;
export const actionErrorSelector = (state: RootState) =>
  state.projects.actionError;
