---
name: geniuz
version: "4.1.1"
description: AI 記憶系統 - 跨會話知識管理，讓 AI 記住修了什麼、為什麼壞掉、如何修好（clawmark 的後繼者）
metadata: {"picoclaw":{"emoji":"📡","requires":{"bins":["bash","geniuz"]}}}
---

# geniuz - AI 記憶系統

> 你的下一個會話是冷啟動。沒有記憶你建了什麼、什麼壞了、你決定了什麼。寫下的每一筆記憶都是給未來會話的禮物。記憶越完整，重新學習的時間越少。

支援任何框架 — Claude Code、Cursor、Windsurf、Aider，或任何能執行 shell 的框架。

**你**（讀到這份文件的 agent）用下面的 CLI：`geniuz remember` 寫，`geniuz recall` 讀。TUI（`geniuz tui`）與圖形 dashboard（`geniuz dashboard`）是給人瀏覽用的，不要從腳本呼叫 — TUI 有 TTY guard，非互動環境會直接拒絕啟動。

先確認可用：`geniuz --version`（目前 4.1.1）。沒有安裝時看專案 README / `install.sh`，不要臆測旗標。

## 為什麼這很重要

一筆寫著「修好 auth bug」的記憶，對未來的你毫無幫助。

一筆寫著什麼壞了、為什麼壞、怎麼修好的記憶，能省下一小時。

記憶會累積。一筆是筆記，一整個資料夾是制度性知識。為那個一無所知的未來的自己而寫。

## 命令速查

```bash
# 保存你學到的 — 管道輸入寫深度，內聯輸入寫快訊
echo "Token validation was running before refresh in auth.rs.
Swapped lines 42-47. Root cause: middleware ordering assumed
sync validation, but OAuth refresh is async. Three edge cases
tested: expired token, revoked token, concurrent refresh." \
  | geniuz remember -c - -g "fix: auth token refresh — async ordering in middleware"

# 快速記憶（不需要深度時）
geniuz remember -c "Upgraded rusqlite to 0.32" -g "dep: rusqlite 0.32"

# 從檔案建立記憶
geniuz remember -c @session-notes.md -g "session: March 19 architecture review"

# 線程化後續記憶
geniuz remember -c "Same fix needed in staging compose" -g "fix: staging auth ordering" -p A1B2C3D4

# 按語意搜尋 — 不是關鍵字
geniuz recall "authentication middleware"
geniuz recall "what broke in production" --since 7d

# 專有名詞（句中大寫字或 "引號" 內容）先做逐字命中
geniuz recall "who reviewed the PR, was it Cubic"

# 精確字詞：回傳「符合的行」，跨全文，新到舊
geniuz recall --grep Cubic --since 7d
geniuz recall --grep Cubic --grep "pull request"   # 每個詞都必須出現

# 整條線程（從任一節點回推 root，root 在前）
geniuz recall --thread A1B2C3D4

# 關鍵字回退（整筆記憶、任一詞命中）
geniuz recall --keyword "auth"

# 最近記憶
geniuz recent
geniuz recent -l 5

# 完整內容（不只 gist）
geniuz recall --full "auth"

# 發現你忘記自己知道的事
geniuz recall --random

# 批量匯入既有檔案
geniuz capture ./docs/
geniuz capture --openclaw

# 建立 embedding 快取（一次，之後自動）
geniuz backfill

# 資料夾統計
geniuz status
```

`recall` 不給查詢時等同 `recent`（套用同一時間窗）。`recall help` 會印說明，不會搜尋「help」這個字。

### 參數細節

| 命令 | 參數 | 說明 |
|---|---|---|
| `remember` | `-c/--content` | 必填；`-` 讀 stdin（TTY 上會直接報錯，不會卡住）、`@path` 讀檔 |
| | `-g/--gist` | 省略時取 content 前 200 字元 — 強烈建議自己寫 |
| | `-p/--parent <前綴>` | 串到既有記憶；**前綴不存在時會靜默變成新的 root**，請先確認 |
| | `--json` | `{ok, action, uuid, embedded}` |
| `recall` | `query` | 省略 = 最近；8/36 碼 hex 視為 UUID 直查 |
| | `--keyword` | 強制關鍵字（LIKE 全表比對） |
| | `--grep <詞>` | 可重複；回符合的行，預設 50 行 |
| | `--thread <ID>` | 預設 100 筆 |
| | `--since/--until` | `24h`、`7d`、`2w`、`2026-09-23`、`2026-09-23 14:00`、RFC 3339 |
| | `-l/--limit` | 語意預設 20、thread 100、grep 50；MCP 端上限 100/500 |
| | `-f/--full`、`--json` | JSON 含 `count`、`memories[]`、`searched{}`、`unembedded` |
| `recent` | `-l`（預設 20）、`--since/--until`、`-f`、`--json` | |
| `capture` | `paths...`、`--split`、`--gist-prefix`、`--dry-run`、`--force`、`--openclaw[=路徑]` | 預設只吃 `.md/.markdown/.txt/.rst/.org`；`--split` 依 `##` 切成 root + 子記憶；**沒有去重，重跑會產生重複記憶** |
| `watch` | `-i`（秒，預設 300）、`-s <UUID>`、`-e "<cmd>"`、`--once`、`--json` | `--exec` 佔位符：`{uuid} {gist} {content} {created_at} {parent} {json}`；以 `sh -c` 執行（Windows 無 sh）；`--once` 目前一律 exit 0，別靠退出碼判斷有沒有新記憶 |
| `backfill` | 無 | 只補沒有 embedding 的記憶 |
| `status` | 無 | 資料夾路徑 + 記憶數 + embedding 覆蓋率（無 `--json`） |
| `mcp` | `serve` / `install [--env K=V]` / `status` | stdio MCP server；工具為 `remember`、`recall`、`recall_recent` |
| `settings` | `list [--json]` / `get <key>` / `set <key> <value>` / `path` | 可用 key：`launch_at_login`、`autoupdate_enabled`、`update_check_frequency`、`recent_memories_count` |

## 共享資料夾

多個 agent 可以寫同一個資料夾。一個 agent 學到的，每個 agent 都找得到。

```bash
GENIUZ_STATION=/shared/team.db geniuz remember -c "Deploy complete" -g "ops: deploy v2.1"
GENIUZ_STATION=/shared/team.db geniuz recall "deploy"
```

| 變數 | 作用 |
|---|---|
| `GENIUZ_HOME` | 資料夾（預設 `~/.geniuz`），`memory.db` 與 `settings.json` 都在裡面 |
| `GENIUZ_STATION` | 直接指定 DB 檔路徑；`settings.json` 仍跟著 `GENIUZ_HOME` |
| `GENIUZ_MODELS_PATH` | 模型快取位置（預設 `$GENIUZ_HOME/models`） |
| `GENIUZ_EMBED_URL` / `GENIUZ_EMBED_MODEL` | 覆寫 Ollama 後端的 endpoint / 模型 |
| `GENIUZ_EMBED_SOCKET` / `GENIUZ_EMBED_SPAWN` | 暖機服務的 socket 名稱 / 連不上時自動 spawn |

沒有 station 清單或命名註冊：每個 process 各自用 `GENIUZ_STATION` 指向不同 `.db`。同一份 DB 靠 WAL + 30 秒 busy timeout 支撐併發。

## 何時 remember

- **解決難題之後。** 你的下一個會話會遇到同樣的問題。給它答案。
- **會話結束之前。** 你 context window 裡的一切都隨會話死亡。你的資料夾不會。
- **發現非顯而易見的東西時。** 小事實 — 哪個設定旗標、哪行程式碼、哪個邊界情況 — 是省最多時間的。

## 何時 recall

- **開始新任務時。** 你可能上週已經解決了部分。
- **卡住時。** 答案可能在你三個會話前寫的記憶裡。
- **壓縮之後。** 你的 context 被壓縮了。你的資料夾沒有。

## 怎麼找東西

語意是**探索**用的：你原本不知道怎麼問的概念與名字。
精確是**回想**用的：誰、何時、發生過嗎、用專有名詞。

1. 問題裡有時間（「上週」「昨天」）就加 `--since`：`7d`、`24h`、`2w` 或日期。不加的話，幾個月前的舊答案會壓過上週的。
2. 先按語意找。每個結果結尾都有 `names seen:` 與 `pointers:` — 那是你的下一跳。
3. 拿找到的東西轉精確：`--grep Devin`，或 `--thread 13625F6B` 讀整段對話。
4. 讀最後一行。`searched: 312 memories · since 7d · grep "Cubic"` 說明了「找不到」的意思是「這個範圍內沒有」。

透過 MCP 時同樣的參數可用：`since`、`until`、`grep`（單詞或陣列）、`thread`。

## 寫好記憶

gist 是未來的你找到這筆記憶的入口。content 是被找到之後讓它有用的東西。

**Gist：** 壓縮洞察。`"fix: auth token refresh — async ordering in middleware"` — 類別、什麼、為什麼、在哪。

**Content：** 讓它自包含。如果未來的你只讀這一筆 — 沒有會話歷史、沒有周邊上下文 — 能理解發生什麼並行動嗎？

記憶不需要長。它需要完整。

**超過一句話的內容：用檔案（`-c @note.md`）或 stdin（`-c -`）。** 內聯形式是 shell 最容易悄悄弄壞的東西 — 反引號會被求值、引號會被吃掉、換行會塌掉，而寫進去的收不回來。

某件事通過了，要寫下**綠燈沒告訴你的事**。通過的測試證明的事，比你以為的要窄。這個落差就是筆記與教訓的差別。

## 記憶是永久的

沒有編輯，沒有刪除 — schema 用 trigger 擋掉 UPDATE / DELETE / INSERT OR REPLACE。如果某筆記憶錯了，用 `-p` 串一筆更正上去。資料夾把走錯的路與修正留在一起，這正是你找到的東西可以信任的原因。

## 運作原理

記憶存在 SQLite（`memory.db`）。payload 是 `{content, gist}` 的 JSON；讀取靠 `json_extract`。語意搜尋用本地多語 BERT 模型 `paraphrase-multilingual-MiniLM-L12-v2`（INT8 ONNX，384 維）— 無 API 呼叫、無雲端、完全離線。首次搜尋時下載一次（約 118MB）。

後端鏈是 **ONNX → 本機 Ollama → 僅關鍵字**：

- 兩個 embedding 後端都掛掉時，`remember` 仍然成功，只印 stderr 提示，該筆記憶只能用關鍵字找，之後跑 `geniuz backfill` 補回。
- 沒有 embedding 的記憶會在 `recall` 輸出裡被標成 partial index（`N memories not embedded`），不是靜默消失。
- `geniuz-embed` 是常駐暖機服務（本地 socket / Windows named pipe），省下每次載入模型約 500ms；沒有它也能跑，只是慢。

搜尋按意義而非關鍵字。「Authentication middleware」會命中一筆講「token validation ordering」的記憶，因為概念重疊。精確路徑（`--keyword`、`--grep`）是對 JSON payload 做 `LIKE` 比對，不是 FTS。排序是對全部向量做線性 cosine — 資料量大時是 O(n)，沒有 ANN 索引。

## 三個介面，一份記憶

| 介面 | 呼叫方式 | 給誰用 |
|---|---|---|
| CLI | `geniuz remember` / `recall` / `recent` … | **agent**（你）、腳本、任何有 shell 的框架 |
| MCP | `geniuz mcp install` → 重啟 Claude Desktop | Claude Desktop 等 MCP client（stdio JSON-RPC） |
| TUI | `geniuz tui` | 人在終端瀏覽（非互動環境拒絕啟動） |
| Dashboard | `geniuz dashboard`（別名 `gui`） | 人在圖形介面瀏覽（macOS menubar / Windows・Linux 系統匣） |

auto-gist、時間窗、thread、grep、harvest 名稱的行為在各介面一致，因為都走同一個 `DatabaseManager`。macOS menubar 是例外：它直接以唯讀 SQLite 讀同一份 DB，所以在 WAL 尚未 checkpoint 時可能落後幾秒。

## 工作區匯入

支援 OpenClaw 工作區（預設路徑 `~/.openclaw/workspace`）：

```bash
geniuz capture --openclaw
geniuz capture --openclaw ~/.openclaw/workspace
```

- `MEMORY.md`（或 `memory.md`）整份成為一筆長期記憶。
- `memory/YYYY-MM-DD.md` 依日期升冪匯入；有多個 `##` 段落時，第一段當 root，其餘串成線程。
- 只切 `##`，不處理 front matter、不處理 `#` / `###`；時間是合成的（每段相隔 2 小時），不是檔案 mtime。

PicoClaw 沒有內建 adapter（clawmark 時代有）。改用一般匯入：

```bash
geniuz capture ~/.picoclaw/workspace/memory/
```

## 從 clawmark 遷移

這個檔案的前身是 clawmark 的 skill。對照：

| clawmark | geniuz |
|---|---|
| `clawmark signal -c … -g …` | `geniuz remember -c … -g …` |
| `clawmark tune "…"` | `geniuz recall "…"` |
| `clawmark tune --keyword` | `geniuz recall --keyword` |
| `clawmark tune --recent` | `geniuz recent` |
| `clawmark tune --full` | `geniuz recall --full` |
| `clawmark tune --random` | `geniuz recall --random` |
| `clawmark capture ./docs/` | `geniuz capture ./docs/` |
| `clawmark backfill` | `geniuz backfill` |
| `clawmark status` | `geniuz status` |
| `-p <id>`（signal 線程） | `-p <前綴>`（相同語意） |
| `CLAWMARK_STATION` | `GENIUZ_STATION` |

新增能力：`--json`（remember/recall/recent/watch）、`--grep` 逐行精確搜尋、`--thread` 整條線程、`--since/--until` 時間窗、`watch` 即時監看、MCP server、TUI、dashboard。

舊 DB 會被就地升級：`signals` 表改名為 `memories` 後套用現行 schema，資料保留。

---

## 版本歷史 / Changelog

### v4.1.1 (2026-10)
- 由 clawmark 改寫為 geniuz：命令面、環境變數、後端鏈（ONNX → Ollama → keyword）、三個介面全部對齊 4.1.1 實作
- 移除 clawmark 的 PicoClaw 匯入敘述（geniuz 沒有此 adapter）
- 保留 picoclaw skill frontmatter 格式

### v0.2.1 (2026-03-31) — clawmark
- 轉換為 picoclaw 格式，加入 frontmatter
