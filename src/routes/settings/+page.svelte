<script>
  import { onMount, tick } from "svelte";
  import { Store } from "@tauri-apps/plugin-store";
  import { emit } from "@tauri-apps/api/event";
  import { confirm } from "@tauri-apps/plugin-dialog";
  import { getCurrentWindow } from "@tauri-apps/api/window";


  // 設定永続化用 Store
  let store;
  let mode = "A";
  
  // デフォルトの時限定義（メイン側と合わせる）
  const defaultPeriods = [
    { label: "1限", start: "08:55", end: "09:45" },
    { label: "2限", start: "09:55", end: "10:45" },
    { label: "3限", start: "10:55", end: "11:45" },
    { label: "4限", start: "11:55", end: "12:45" },
    { label: "5限", start: "13:25", end: "14:15" },
    { label: "6限", start: "14:25", end: "15:15" }
  ];

  const PRESET_A = defaultPeriods;
  const PRESET_B = [
    { label: "1限", start: "08:55", end: "09:40" },
    { label: "2限", start: "09:50", end: "10:35" },
    { label: "3限", start: "10:45", end: "11:30" },
    { label: "4限", start: "11:40", end: "12:25" },
    { label: "5限", start: "13:05", end: "13:50" },
    { label: "6限", start: "14:00", end: "14:45" }
  ];

  function deepCopyPeriods(arr) {
    return arr.map((p) => ({ ...p }));
  }

  // 6時限固定：Storeの中身が古い/壊れている場合を検出（パターン1）
  function isValidPeriods(x) {
    return Array.isArray(x) && x.length === 6 && x.every(p => p && typeof p.label==="string" && typeof p.start==="string" && typeof p.end==="string");
  }

  // ユーザーが恒久設定するA/B（初期値はハードコードを使用）
  let presetA = deepCopyPeriods(PRESET_A);
  let presetB = deepCopyPeriods(PRESET_B);
  let customPeriods = deepCopyPeriods(PRESET_A);

  // 画面上で編集・表示する配列
  // （テンプレート側が {#each periods as period} を使っているので名前を periods に統一）
  let periods = deepCopyPeriods(PRESET_A);

  // 「✔️」を出すためのフラグ（テンプレートで showCheck を使っている）
  let showCheck = false;

  // 起動時に Store から periods を読む
  onMount(async () => {
    try {
      store = await Store.load("settings.json");
      const storedMode = await store.get("mode");
      const stored = await store.get("periods");
      const storedA = await store.get("presetA");
      const storedB = await store.get("presetB");
      const storedCustom = await store.get("customPeriods");
      console.log("📦 settings画面: Storeから取得したperiods:", stored);

      if (storedMode === "A" || storedMode === "B" || storedMode === "custom") {
        mode = storedMode;
      }

      if (isValidPeriods(storedA)) presetA = storedA;
      if (isValidPeriods(storedB)) presetB = storedB;
      if (isValidPeriods(storedCustom)) customPeriods = storedCustom;
      else customPeriods = deepCopyPeriods(presetA); // custom初期値はA相当


      if (mode === "A") periods = deepCopyPeriods(presetA);
      else if (mode === "B") periods = deepCopyPeriods(presetB);
      else {
      // custom：表示はcustomPeriods。stored(periods)は「現在適用中」なので使わない
      periods = deepCopyPeriods(customPeriods);
      }

    } catch (e) {
      console.error("⚠️ settings画面: Storeの読み込みに失敗。デフォルト値を使用します。", e);
    }
  });

  function applyMode(nextMode) {
    mode = nextMode;
    if (mode === "A") periods = deepCopyPeriods(presetA);
    else if (mode === "B") periods = deepCopyPeriods(presetB);
    else periods = deepCopyPeriods(customPeriods); // customは自分の値を表示

    // A/B選択時だけ自動保存
    if (nextMode === "A" || nextMode === "B") {
      autoSave();
    }
  }
  
  async function autoSave() {
    try {
      if (!store) store = await Store.load("settings.json");
      await store.set("mode", mode);
      await store.set("periods", periods);
      await store.save();
      await emit("update-periods", periods);
      showCheck = true;
      setTimeout(() => { showCheck = false; }, 1000);
    } catch (e) {
      console.error("自動保存失敗:", e);
    }
  }


  // 保存ボタン用（テンプレートの on:click={sendPeriods} と対応）
  async function sendPeriods() {
    try {
      if (!store) {
        store = await Store.load("settings.json");
      }

      // 1. Store に保存（選択中モードの内容を恒久化）
      if (mode === "A") { presetA = deepCopyPeriods(periods); await store.set("presetA", presetA); await store.set("periods", presetA); }
      else if (mode === "B") { presetB = deepCopyPeriods(periods); await store.set("presetB", presetB); await store.set("periods", presetB); }
      else {
        customPeriods = deepCopyPeriods(periods);
        await store.set("customPeriods", customPeriods); // customはここに保存して記憶
        await store.set("periods", periods);            // 現在適用中としても保存（メイン反映用）
      }      
      await store.set("mode", mode);
      await store.save();
      console.log("settings画面: periods を Store に保存しました:", periods);

      // 2. メイン画面に通知（メイン側で listen("update-periods") している前提）
      await emit("update-periods", periods); // ← payloadは変えない（メイン側修正不要）

      // 3. ✔️ を一瞬表示
      showCheck = true;
      setTimeout(() => {
        showCheck = false;
      }, 1000);
    } catch (e) {
      console.error("settings画面: 保存に失敗しました", e);
    }
  }

  // 初期化：Storeをクリアして「インストール直後の状態」に戻す（ファイルは残る）
  async function resetSettings() {
    const ok = await confirm("時間設定を初期化します。よろしいですか？");
    if (!ok) return;
    try {
      if (!store) store = await Store.load("settings.json");
      await store.clear();
      presetA = deepCopyPeriods(PRESET_A);
      presetB = deepCopyPeriods(PRESET_B);
      customPeriods = deepCopyPeriods(PRESET_A);
      mode = "A";
      periods = deepCopyPeriods(PRESET_A); // ←画面の入力がこれを参照しているので明示的に差し替える
      console.log("reset periods", periods.map(p => `${p.start}-${p.end}`));
      console.log("mode after reset", mode);

      await tick();      // DOMに反映させてから
      await sendPeriods();
      await autoSave();  // ←既存の自動保存を流用（✔️点灯 + emit もここで実行）
    } catch (e) {
      console.error("settings画面: 初期化に失敗しました", e);
    }
  }

  // Enterキーで保存（time入力中でも反応）
  function onTimeEnter(e) {
    if (e.key === "Enter") {
      e.preventDefault();
      sendPeriods();
    }
  }

   // 設定画面を閉じる（settingsウィンドウのみ）
  async function closeSettings() {
    try {
      await getCurrentWindow().close();
    } catch (e) {
      console.error("settings画面: closeに失敗しました", e);
    }
  }
</script>

<main>
  <span class="mode">現在: {mode}校時</span>

  {#each periods as period, i}
    <div>
      <label for={"start-" + i}>{period.label}</label>
      <input id={"start-" + i} type="time" bind:value={period.start} on:keydown={onTimeEnter} /> -
      <input id={"end-" + i} type="time" bind:value={period.end} on:keydown={onTimeEnter} aria-label={period.label + " 終了"} />
    </div>
  {/each}

  <!-- A/B 切り替え -->
  <div class="preset">
    <button type="button" class:selected={mode === "A"} on:click={() => applyMode("A")}>Ａ</button>
    <button type="button" class:selected={mode === "B"} on:click={() => applyMode("B")}>Ｂ</button>
    <button on:click={sendPeriods}>保存</button>
    <span class="checkmark" style:visibility={showCheck ? "visible" : "hidden"}>✔️</span>
  </div>
  <div class="preset preset-custom">
    <button type="button" class:selected={mode === "custom"} on:click={() => applyMode("custom")}>custom</button>
    <button type="button" class="close-btn" on:click={closeSettings}>閉じる</button>
  </div>
    <div class="preset preset-reset">
    <button type="button" class="reset" on:click={resetSettings}>初期化</button>
  </div>
</main>

<style>
  main {
    margin-top: 1rem;
    padding: 1rem;
    font-family: sans-serif;
    position: relative;
  }
  label {
    margin-right: 0.5rem;
  }
  input {
    margin: 0.2rem;
  }
  .button-wrapper {
    position: absolute;
    bottom: -15px;
    right: 30px;
    display: flex;
    justify-content: flex-end;
    align-items: flex-end;
    gap: 0.1rem;
    height: 2.5rem;
  }
  button {
    margin-top: 1rem;
    font-size: 0.9rem;
    float: right;
  }
  .checkmark {
    position: relative;
    top: 0.7em;
    font-size: 0.7rem;
    line-height: 1;
    right: 0;
    min-width: 1.5rem;
    text-align: center;
  }
  .preset {
    display: flex;
    gap: 0.5rem;
    align-items: center;
    margin-bottom: 0.75rem;
  }
  .preset-reset { margin-top: -0.25rem; }
  .preset button:nth-child(2) { margin-right: 0.3rem; }
  .preset button.selected {
    font-weight: 700;
  }
  .preset-custom { margin-top: -1rem; }
  .mode {
    font-size: 0.9rem;
    opacity: 0.8;
  }
</style>
