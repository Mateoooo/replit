import { configureStore } from "@reduxjs/toolkit";
import {
  useDispatch as dispatchHook,
  useSelector as selectorHook,
  type TypedUseSelectorHook,
} from "react-redux";
import userReducer from "./slices/user";
import projectsReducer from "./slices/projects";

export const store = configureStore({
  reducer: {
    user: userReducer,
    projects: projectsReducer,
  },
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;

export const useDispatch: () => AppDispatch = dispatchHook;
export const useSelector: TypedUseSelectorHook<RootState> = selectorHook;
