export type ProjectStatus = "created" | "running" | "stopped" | "failed";

export type Project = {
  id: number;
  name: string;
  status: ProjectStatus;
  lastRunAt: string | null;
  createdAt: string;
  archiveFilename: string | null;
  activeRunId: number | null;
};

export type RunStatus = "pending" | "running" | "finished" | "failed" | "stopped";

export type Run = {
  id: number;
  projectId: number;
  status: RunStatus;
  startedAt: string | null;
  finishedAt: string | null;
  exitCode: number | null;
  errorMessage: string | null;
  hostPort: number | null;
  previewUrl: string | null;
  createdAt: string;
};

export type LogEntry = {
  id: number;
  runId: number;
  stream: "stdout" | "stderr" | "system";
  content: string;
  loggedAt: string;
};

export type LogsResponse = {
  logs: LogEntry[];
  lastId: number | null;
  lastTimestamp: string | null;
  runStatus: RunStatus;
};

export type CommandExecution = {
  id: number;
  runId: number;
  command: string;
  output: string;
  exitCode: number | null;
  status: "pending" | "running" | "completed" | "failed";
  startedAt: string | null;
  finishedAt: string | null;
  createdAt: string;
};
