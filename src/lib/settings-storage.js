import { BaseDirectory, executableDir, join, localDataDir } from "@tauri-apps/api/path";
import { mkdir, readTextFile, writeTextFile } from "@tauri-apps/plugin-fs";

const APP_SETTINGS_DIR_NAME = "clock_app";
const SETTINGS_FILE_NAME = "settings.json";
const SETTINGS_RELATIVE_PATH = `${APP_SETTINGS_DIR_NAME}/${SETTINGS_FILE_NAME}`;

function isWindows() {
  return typeof navigator !== "undefined" && navigator.userAgent.includes("Windows");
}

function isTauriDevServer() {
  return typeof window !== "undefined" && window.location.origin.startsWith("http://localhost:");
}

function useExecutableDirStore() {
  return isWindows() && !isTauriDevServer();
}

async function getSettingsPaths() {
  if (useExecutableDirStore()) {
    const dirPath = await executableDir();
    const filePath = await join(dirPath, SETTINGS_FILE_NAME);
    return { dirPath, filePath };
  }

  const localDir = await localDataDir();
  const dirPath = await join(localDir, APP_SETTINGS_DIR_NAME);
  const filePath = await join(dirPath, SETTINGS_FILE_NAME);
  return { dirPath, filePath };
}

async function ensureSettingsDir() {
  if (useExecutableDirStore()) {
    return;
  }

  await mkdir(APP_SETTINGS_DIR_NAME, {
    baseDir: BaseDirectory.LocalData,
    recursive: true
  });
}

export async function loadSettingsFile() {
  try {
    if (useExecutableDirStore()) {
      const raw = await readTextFile(SETTINGS_FILE_NAME, {
        baseDir: BaseDirectory.Executable
      });
      return JSON.parse(raw);
    }

    const raw = await readTextFile(SETTINGS_RELATIVE_PATH, {
      baseDir: BaseDirectory.LocalData
    });
    return JSON.parse(raw);
  } catch (e) {
    return null;
  }
}

export async function saveSettingsFile(data) {
  await ensureSettingsDir();
  if (useExecutableDirStore()) {
    await writeTextFile(SETTINGS_FILE_NAME, JSON.stringify(data), {
      baseDir: BaseDirectory.Executable
    });
    return;
  }

  await writeTextFile(SETTINGS_RELATIVE_PATH, JSON.stringify(data), {
    baseDir: BaseDirectory.LocalData
  });
}

export async function getSettingsFilePath() {
  const { filePath } = await getSettingsPaths();
  return filePath;
}
