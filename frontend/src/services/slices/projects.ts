import { createSlice, createAsyncThunk } from "@reduxjs/toolkit";
import {
  getProjectsApi,
  createProjectApi,
  deleteProjectApi,
  startProjectApi,
  stopProjectApi,
  errorMessage,
} from "../api";
import type { Project, Run } from "../types";
import { logoutUser, userLogout } from "./user";

type TProjectsState = {
  items: Project[];
  loaded: boolean;
  loading: boolean;
  error: string | null;
  createRequest: boolean;
  createError: string | null;
  actionError: string | null;
};

const initialState: TProjectsState = {
  items: [],
  loaded: false,
  loading: false,
  error: null,
  createRequest: false,
  createError: null,
  actionError: null,
};

export const fetchProjects = createAsyncThunk(
  "projects/fetch",
  async (_, { rejectWithValue }) => {
    try {
      return (await getProjectsApi()).projects;
    } catch (err: any) {
      return rejectWithValue(errorMessage(err, "Не удалось загрузить проекты"));
    }
  }
);

export const createProject = createAsyncThunk(
  "projects/create",
  async (
    { name, archive }: { name: string; archive: File },
    { rejectWithValue }
  ) => {
    try {
      return (await createProjectApi(name, archive)).project;
    } catch (err: any) {
      return rejectWithValue(errorMessage(err, "Не удалось создать проект"));
    }
  }
);

export const startProject = createAsyncThunk<
  Run,
  number,
  { rejectValue: string }
>("projects/start", async (id, { dispatch, rejectWithValue }) => {
  try {
    const { run } = await startProjectApi(id);
    await dispatch(fetchProjects());
    return run;
  } catch (err: any) {
    return rejectWithValue(errorMessage(err, "Не удалось запустить проект"));
  }
});

export const stopProject = createAsyncThunk<
  Run,
  number,
  { rejectValue: string }
>("projects/stop", async (id, { dispatch, rejectWithValue }) => {
  try {
    const { run } = await stopProjectApi(id);
    await dispatch(fetchProjects());
    return run;
  } catch (err: any) {
    return rejectWithValue(errorMessage(err, "Не удалось остановить проект"));
  }
});

export const deleteProject = createAsyncThunk<
  number,
  number,
  { rejectValue: string }
>("projects/delete", async (id, { rejectWithValue }) => {
  try {
    await deleteProjectApi(id);
    return id;
  } catch (err: any) {
    return rejectWithValue(errorMessage(err, "Не удалось удалить проект"));
  }
});

const projectsSlice = createSlice({
  name: "projects",
  initialState,
  reducers: {
    clearCreateError: (state) => {
      state.createError = null;
    },
    clearActionError: (state) => {
      state.actionError = null;
    },
  },
  extraReducers: (builder) => {
    builder
      // список
      .addCase(fetchProjects.pending, (state) => {
        if (!state.loaded) state.loading = true;
      })
      .addCase(fetchProjects.fulfilled, (state, action) => {
        state.items = action.payload;
        state.loading = false;
        state.loaded = true;
        state.error = null;
      })
      .addCase(fetchProjects.rejected, (state, action) => {
        state.loading = false;
        state.loaded = true;
        state.error = action.payload as string;
      })
      // создание
      .addCase(createProject.pending, (state) => {
        state.createRequest = true;
        state.createError = null;
      })
      .addCase(createProject.fulfilled, (state, action) => {
        state.createRequest = false;
        state.items.unshift(action.payload);
      })
      .addCase(createProject.rejected, (state, action) => {
        state.createRequest = false;
        state.createError = action.payload as string;
      })
      // старт / стоп / удаление
      .addCase(startProject.pending, (state) => {
        state.actionError = null;
      })
      .addCase(startProject.rejected, (state, action) => {
        state.actionError = action.payload ?? "Ошибка";
      })
      .addCase(stopProject.pending, (state) => {
        state.actionError = null;
      })
      .addCase(stopProject.rejected, (state, action) => {
        state.actionError = action.payload ?? "Ошибка";
      })
      .addCase(deleteProject.pending, (state) => {
        state.actionError = null;
      })
      .addCase(deleteProject.fulfilled, (state, action) => {
        state.items = state.items.filter((p) => p.id !== action.payload);
      })
      .addCase(deleteProject.rejected, (state, action) => {
        state.actionError = action.payload ?? "Ошибка";
      })
      // при выходе очищаем всё
      .addCase(logoutUser.fulfilled, () => initialState)
      .addCase(userLogout, () => initialState);
  },
});

export const { clearCreateError, clearActionError } = projectsSlice.actions;
export default projectsSlice.reducer;
