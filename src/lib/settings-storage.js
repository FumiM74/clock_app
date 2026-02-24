import { join, localDataDir } from "@tauri-apps/api/path";
import { mkdir, readTextFile, writeTextFile } from "@tauri-apps/plugin-fs";

const APP_SETTINGS_DIR_NAME = "clock_app";
const SETTINGS_FILE_NAME = "settings.json";

async function getSettingsPaths() {
  const localDir = await localDataDir();
  const dirPath = await join(localDir, APP_SETTINGS_DIR_NAME);
  const filePath = await join(dirPath, SETTINGS_FILE_NAME);
  return { dirPath, filePath };
}

async function ensureSettingsDir() {
  const { dirPath } = await getSettingsPaths();
  await mkdir(dirPath, { recursive: true });
}

export async function loadSettingsFile() {
  try {
    const { filePath } = await getSettingsPaths();
    const raw = await readTextFile(filePath);
    return JSON.parse(raw);
  } catch (e) {
    return null;
  }
}

export async function saveSettingsFile(data) {
  await ensureSettingsDir();
  const { filePath } = await getSettingsPaths();
  await writeTextFile(filePath, JSON.stringify(data));
}

export async function getSettingsFilePath() {
  const { filePath } = await getSettingsPaths();
  return filePath;
}
