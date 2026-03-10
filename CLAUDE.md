# CLAUDE.md

このファイルは、リポジトリ内のコードを扱う Claude Code (claude.ai/code) へのガイダンスを提供します。

## アプリの概要

学校の時間割を管理するための小型デスクトップ時計アプリ。現在時刻・現在のコマ名・次のコマまでの残り分数を表示する。Tauri v2（Rustバックエンド）+ SvelteKit（フロントエンド）で構築。

メインウィンドウ: 70×120px。設定ウィンドウ（250×420px）はTauriによってメインウィンドウから動的に生成される。

## コマンド

```bash
# フロントエンド開発サーバー（ポート1420）
npm run dev

# Svelteコンポーネントの型チェック
npm run check
npm run check:watch

# フロントエンドのみビルド（./build に出力）
npm run build

# Tauriアプリ開発モード（Rust + フロントエンドを同時起動）
npm run tauri dev

# 配布用ビルド（macOS DMG / Windows NSIS）
npm run tauri build
```

テストフレームワークは未設定。

## アーキテクチャ

**スタック**: `adapter-static`（プリレンダリング・SSRなし）を使ったSvelteKit + Tauri v2（Rust）。全ページに `export const prerender = true; export const ssr = false;` を設定。

**2つのウィンドウ**:
- `/` — メインの時計表示（`src/routes/+page.svelte`）
- `/settings` — スケジュール編集画面（`src/routes/settings/+page.svelte`）、メインウィンドウからTauri経由で動的に開く

**IPC パターン**: 設定保存時に設定ページがTauriイベント（`update-periods`）を発行し、メインページがそれを受信してリロードなしでコマ情報を更新する。

**設定の永続化**: プラットフォーム固有のローカルデータディレクトリにJSONファイルとして保存（例: `%LOCALAPPDATA%\clock_app\settings.json`）。読み書きは `src/lib/settings-storage.js` でTauriの `fs` / `path` プラグインを使って処理。

**使用Tauriプラグイン**: `dialog`、`fs`、`log`。ケイパビリティは `src-tauri/capabilities/` で定義。

**CI/CD**: GitHub Actionsワークフロー（`.github/workflows/build.yml`）、手動トリガー。`tauri-apps/tauri-action` でmacOS DMGとWindows NSISインストーラーをビルド。

**Windowsインストーラー**: `setup_clock_app.bat` がインストールを統括（インストーラーのコピー・Windows Defenderの除外設定・NSISランチャー起動）。カスタムNSISフックは `src-tauri/nsis/` に配置。
