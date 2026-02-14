<script>
  import { onMount } from "svelte";
  import { listen } from "@tauri-apps/api/event";
  import { Store } from "@tauri-apps/plugin-store";

  // ★追加：設定永続化用の Store インスタンス
  let store;

  let time = "";
  let period = "";
  let minutesLeft = "";

  // デフォルトの時限定義（起動時・Storeに何もないとき用）
  let basePeriods = [
    { label: "1限", start: "08:55", end: "09:45" },
    { label: "2限", start: "09:55", end: "10:45" },
    { label: "3限", start: "10:55", end: "11:45" },
    { label: "4限", start: "11:55", end: "12:45" },
    { label: "5限", start: "13:25", end: "14:15" },
    { label: "6限", start: "14:25", end: "15:15" }
  ];

  let periods = [];

  // 拡張関数：休憩・昼休み・放課後を自動挿入
  function expandPeriods(base) {
    const expanded = [];

    for (let i = 0; i < base.length; i++) {
      const current = base[i];
      expanded.push(current);

      const next = base[i + 1];
      if (next) {
        const currentEnd = current.end;
        const nextStart = next.start;
        let label = "";
        if (i === 0) label = "休憩①";
        else if (i === 1) label = "休憩②";
        else if (i === 2) label = "休憩③";
        else if (i === 3) label = "昼休み";
        else if (i === 4) label = "休憩⑤";

        if (label) {
          expanded.push({
            label,
            start: currentEnd,
            end: nextStart
          });
        }
      }
    }

    // 放課後を追加
    const last = base[base.length - 1];
    if (last) {
      expanded.push({
        label: "放課後",
        start: last.end,
        end: "23:59"
      });
    }

    return expanded;
  }

  function updateTime() {
    // 時限と残り時間を更新
    const now = new Date();
    time = now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    const hour = now.getHours();
    const minute = now.getMinutes();
    const totalMinutes = hour * 60 + minute;

    period = "放課後";
    minutesLeft = "";

    for (const p of periods) {
      const [startH, startM] = p.start.split(":").map(Number);
      const [endH, endM] = p.end.split(":").map(Number);
      const startMin = startH * 60 + startM;
      const endMin = endH * 60 + endM;

      if (totalMinutes >= startMin && totalMinutes < endMin) {
        period = p.label;
        minutesLeft = endMin - totalMinutes;
        break;
      }
    }
  }

  // 設定画面の表示
  async function openSettings() {
    if (typeof window === "undefined") return;
    const { WebviewWindow } = await import("@tauri-apps/api/webviewWindow");
    const existing = await WebviewWindow.getByLabel("settings");
    console.log("🧪 getByLabel result:", existing);

    if (existing) {
      await existing.show?.(); // ウィンドウを前面に出す
      return;
    }

    const settings = new WebviewWindow("settings", {
      url: "/settings",
      width: 200,
      height: 420,
      resizable: true,
      decorations: true
    });

    settings.once("tauri://created", () => {
      console.log("✅ settings ウィンドウが作成されました");
    });
    settings.once("tauri://error", (e) => {
      console.error("settings ウィンドウの作成に失敗", e);
    });
  }

  onMount(async () => {
    // ★変更ポイント①：起動時に Store から periods を読み込む
    try {
      store = await Store.load("settings.json");
      const stored = await store.get("periods");
      console.log("📦 Storeから取得したperiods:", stored);

      if (Array.isArray(stored) && stored.length > 0) {
        basePeriods = stored;
      } else {
        console.warn("⚠️ 設定が未保存または不正な形式です。デフォルト値を使用します。");
      }
    } catch (e) {
      console.error("⚠️ Storeの読み込みに失敗しました。デフォルト値を使用します。", e);
    }

    // ここで一度だけ展開
    periods = expandPeriods(basePeriods);
    console.log("現在のperiods:", periods);

    updateTime();
    setInterval(updateTime, 1000);

    // ★変更ポイント②：設定画面からの更新イベント
    listen("update-periods", (event) => {
      console.log("受信:", event.payload);

      if (Array.isArray(event.payload) && event.payload.length > 0) {
        basePeriods = event.payload;
        periods = expandPeriods(basePeriods);
      }
    });
  });
</script>


<main style="
  width: 100%;
  height: 100%;
  font-size: 1em;
  text-align: center;
  user-select: none;
  display: flex;
  justify-content: center;
  align-items: center;
  position: relative; /* ← ボタンの absolute 基準 */
  box-sizing: border-box;
">

  <!-- テキスト：中央配置する要素 -->
  <div id="text-block"
    style="
      white-space: pre-line;
      line-height: 1.4;
    ">
    {time}
    {#if period}
      {'\n'}{period}
      {#if period !== "放課後"}
        {'\n'}<span style="font-size: 0.7em; position: relative; top: -6px;">あと</span><span style="position: relative; top: -6px;">{minutesLeft} </span><span style="font-size: 0.7em; position: relative; top: -6px;">分</span>
      {/if}
    {/if}
  </div>

  <!-- 歯車：テキストの真下 & 横方向は中央 -->
  <button aria-label="設定"
    on:click={openSettings}
    style="
      position: absolute;
      left: calc(50% + 4px);  /* 横は中央から少し右 */
      translate: -50% 0;      /* 中央合わせ */

      /* ★ テキストの真下に置く基準 */
      top: calc(50% + 1.3em); 
      /* ↑ 50%（テキストの中央）からテキスト高さ分だけ下へ */

      font-size: 1em;
      padding: 0;
      cursor: pointer;
      border: none;
      background: transparent;
      outline: none;
      width: 32px;
      height: 32px;
      display: flex;
      align-items: center;
      justify-content: center;
    ">
    <svg xmlns="http://www.w3.org/2000/svg" width="25" height="25" viewBox="0 0 35 35" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M10.325 4.317c.426-1.756 3.084-1.756 3.51 0a1.724 1.724 0 0 0 2.591 1.1c1.518-.888 3.286.88 2.4 2.397a1.724 1.724 0 0 0 1.098 2.592c1.756.426 1.756 3.084 0 3.51a1.724 1.724 0 0 0-1.098 2.591c.887 1.518-.882 3.286-2.4 2.4a1.724 1.724 0 0 0-2.591 1.098c-.426 1.756-3.084 1.756-3.51 0a1.724 1.724 0 0 0-2.592-1.098c-1.518.886-3.286-.882-2.4-2.4a1.724 1.724 0 0 0-1.098-2.591c-1.756-.426-1.756-3.084 0-3.51a1.724 1.724 0 0 0 1.098-2.592c-.886-1.518.882-3.285 2.4-2.397a1.724 1.724 0 0 0 2.592-1.1z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  </button>

</main>
