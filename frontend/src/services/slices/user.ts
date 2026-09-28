import { createSlice, createAsyncThunk } from "@reduxjs/toolkit";
import {
  registerApi,
  loginApi,
  logoutApi,
  getUserApi,
} from "../api";
import { setCookie, deleteCookie } from "../utils/cookie";

type TUser = { id: number; email: string };

type TUserState = {
  isAuthChecked: boolean;
  isAuthenticated: boolean;
  data: TUser | null;
  loginUserError: string | null;
  loginUserRequest: boolean;
};

const initialState: TUserState = {
  isAuthChecked: false,
  isAuthenticated: false,
  data: null,
  loginUserError: null,
  loginUserRequest: false,
};

type TCredentials = { email: string; password: string };

export const registerUser = createAsyncThunk(
  "user/registerUser",
  async ({ email, password }: TCredentials, { rejectWithValue }) => {
    try {
      const data = await registerApi(email, password);
      setCookie("accessToken", data.accessToken);
      localStorage.setItem("refreshToken", data.refreshToken);
      return data.user;
    } catch (err: any) {
      return rejectWithValue(err.errors?.join(", ") ?? "Ошибка регистрации");
    }
  }
);

export const loginUser = createAsyncThunk(
  "user/loginUser",
  async ({ email, password }: TCredentials, { rejectWithValue }) => {
    try {
      const data = await loginApi(email, password);
      setCookie("accessToken", data.accessToken);
      localStorage.setItem("refreshToken", data.refreshToken);
      return data.user;
    } catch (err: any) {
      return rejectWithValue(err.error ?? "Ошибка входа");
    }
  }
);

export const logoutUser = createAsyncThunk("user/logoutUser", async () => {
  const refreshToken = localStorage.getItem("refreshToken");
  if (refreshToken) {
    await logoutApi(refreshToken).catch(() => {});
  }
  localStorage.removeItem("refreshToken");
  deleteCookie("accessToken");
});

export const checkUserAuth = createAsyncThunk(
  "user/checkUser",
  async (_, { dispatch }) => {
    const token = document.cookie.includes("accessToken");
    if (token) {
      await dispatch(getUser()).catch(() => {});
    }
    dispatch(authChecked());
  }
);

export const getUser = createAsyncThunk(
  "user/getUser",
  async (_, { rejectWithValue }) => {
    try {
      const data = await getUserApi();
      return data.user;
    } catch (err: any) {
      return rejectWithValue(err.error ?? "Не авторизован");
    }
  }
);

export const userSlice = createSlice({
  name: "user",
  initialState,
  reducers: {
    authChecked: (state) => {
      state.isAuthChecked = true;
    },
    userLogout: (state) => {
      state.data = null;
      state.isAuthenticated = false;
    },
  },
  extraReducers: (builder) => {
    builder
      // register
      .addCase(registerUser.pending, (state) => {
        state.loginUserRequest = true;
        state.loginUserError = null;
      })
      .addCase(registerUser.rejected, (state, action) => {
        state.loginUserRequest = false;
        state.loginUserError = action.payload as string;
        state.isAuthChecked = true;
      })
      .addCase(registerUser.fulfilled, (state, action) => {
        state.data = action.payload;
        state.isAuthenticated = true;
        state.loginUserRequest = false;
        state.isAuthChecked = true;
      })
      // login
      .addCase(loginUser.pending, (state) => {
        state.loginUserRequest = true;
        state.loginUserError = null;
      })
      .addCase(loginUser.rejected, (state, action) => {
        state.loginUserRequest = false;
        state.loginUserError = action.payload as string;
        state.isAuthChecked = true;
      })
      .addCase(loginUser.fulfilled, (state, action) => {
        state.data = action.payload;
        state.isAuthenticated = true;
        state.loginUserRequest = false;
        state.isAuthChecked = true;
      })
      // logout
      .addCase(logoutUser.fulfilled, (state) => {
        state.data = null;
        state.isAuthenticated = false;
      })
      // get user
      .addCase(getUser.fulfilled, (state, action) => {
        state.data = action.payload;
        state.isAuthenticated = true;
      })
      .addCase(getUser.rejected, (state) => {
        state.data = null;
        state.isAuthenticated = false;
      });
  },
});

export const { authChecked, userLogout } = userSlice.actions;
export default userSlice.reducer;