# git-sync-multi
批次管理多個 Git 專案的同步與備份工具。

## 🛠️ 工具清單

### 1. batch_gh_create.ps1 (批次 GitHub 倉庫建立)
這個工具可以讓您在多個 GitHub 帳號下快速同步建立多個 Repository，並自動處理權限與本地關聯。

#### 功能特點
- **多帳號自動切換**：自動偵測 `gh auth status` 中的帳號並執行 `gh auth switch`。
- **雙檔案配置**：透過 `accounts.txt` 管理帳號，`projects.txt` 管理專案名稱與參數。
- **智慧過濾**：自動跳過已存在的專案，若為私人或 Fork 專案會發出明顯警告。
- **自動關聯**：若本地已存在資料夾且無遠端關聯，自動執行 `git init`、`commit` 並推送到新建立的遠端。

#### 使用方法
- 在 `ini/accounts.txt` 填入 GitHub 帳號清單。
- 在 `ini/projects.txt` 填入專案資訊（例如：`my-repo --public`）。
- 執行：`./batch_gh_create.ps1`
- **日誌紀錄**：所有的成功、跳過或錯誤原因都會紀錄在 `logs/create_log.log`。

---

### 2. batch_git_pull.ps1 (批次更新)
自動掃描指定目錄下的所有子資料夾，若發現為 Git 倉庫，則自動執行 `git pull` 以同步遠端更新。

#### 功能特點
- **自動切換帳號**：啟動時自動讀取 `.env` 中的 `GITHUB_ACCOUNT` 並切換，確保更新權限。

#### 使用方法
- 在 PowerShell 中執行：`./batch_git_pull.ps1`
- **錯誤記錄**：若執行過程中發生錯誤，將會記錄在 `logs/git_pull_errors.log` 中。

---

### 3. batch_create_git_sync.ps1 (批次初始化)
批次為每個子目錄建立 `setup_git_sync.ps1` 同步設定腳本。

#### setup_git_sync.ps1 特色
每個生成的腳本現在都具備 **等冪性 (Idempotence)** / **自愈能力**：
- **自動歸零**：執行時會先強制清除所有的 `pushurl` 設定。
- **防止堆疊**：即使多次重複執行腳本，位址清單依然會保持正確的順序與數量（4 筆紀錄）。
- **同步備份**：依序設定主要帳號與備份帳號，確保一鍵即可同步推送至所有遠端。

#### 使用方法
- 在 PowerShell 中執行：`./batch_create_git_sync.ps1`
- 進入子目錄執行：`./setup_git_sync.ps1`

---

### 4. batch_git_status.ps1 (批次狀態檢查)
檢查 `ROOT_PATH` 下所有 Git 專案是否有未提交的異動。

#### 功能特點
- **自動切換帳號**：啟動時自動讀取 `.env` 中的 `GITHUB_ACCOUNT` 並切換，確保抓取權限。
- **自動抓取描述**：異動專案會自動從 GitHub 抓取專案描述並記錄於 Log。
- **智慧過濾顯示**：畫面僅顯示「公開、非 Fork」的專案異動。
- **記錄分流**：Private 或 Fork 專案的異動會默默記錄於 Log，不干擾畫面。

#### 使用方法
- 在 PowerShell 中執行：`./batch_git_status.ps1`
- **日誌檔案**：`logs/git_status_changed.log` (每次執行自動清空)

---

### 5. batch_git_remote.ps1 (批次遠端檢查與導出)
掃描 `ROOT_PATH` 下所有 Git 專案的遠端位址 (`git remote -v`)，並自動分類與導出可用清單。

#### 功能特點
- **自動切換帳號**：啟動時自動讀取 `.env` 中的 `GITHUB_ACCOUNT` 並切換，確保抓取權限。
- **中文狀態提示**：
    - `[✅ 已導出 ...]`：符合條件並成功寫入清單。
    - `[⏭️ 已跳過]`：因私有、分支、或完成標記而排除。
- **三路 Log 分流** (存於 `./logs/`)：
    - **`git_remote_list.log`**: 完整掃描紀錄。
    - **`excluded_projects.log`**: 詳細記錄每個專案被略過的原因。
    - **`git_remote_debug.log`**: 紀錄擁有 3 筆以上遠端位址的複雜專案。
- **自動導出清單**：自動將標準公開專案導出至 **`out/extracted_projects.txt`**。
- **智慧過濾**：
    - 自動排除 **Private (私人)** 與 **Fork** 專案（畫面會提示原因）。
    - 自動排除 Description 開頭為 **✅** 的已完成專案（畫面會提示原因）。
- **魯棒性解析**：支援專案名稱中包含點（.）的 URL 解析（如 `Nuxt.js-test`）。

#### 使用方法
- 在 PowerShell 中執行：`./batch_git_remote.ps1`
- **結果檔案**：
    - 標準清單：`logs/git_remote_list.log`
    - 調試合併：`logs/git_remote_debug.log`
    - 導出專案：`out/extracted_projects.txt`

---

## ⚙️ 配置說明

### 1. 環境變數 (.env)
請將 `.env.example` 複製為 `.env` 並根據您的環境修改：
```text
ROOT_PATH="D:\github\chiisen\"      # 所有專案存放的根目錄
GITHUB_ACCOUNT=your_username        # 您的主要 GitHub 帳號
```

### 2. 帳號清單 (ini/accounts.txt)
列出所有受管理的 GitHub 帳號（需已透過 `gh auth login` 登入）：
- 格式：每行一個帳號名稱。
- 範例請參考 `ini/accounts.txt.example`。

### 3. 專案清單 (ini/projects.txt)
列出您想要巡檢或建立的專案名稱與 `gh` 參數：
- 格式：`[專案名稱] [可選參數]`。
- 範例請參考 `ini/projects.txt.example`。
- **支援參數**：可加入 `--public`, `--private`, `--description "..."`, `--license mit` 等所有 GitHub CLI 支援的參數。

---

## � 日誌紀錄 (Logs)

本工具產生的日誌檔案均存放在 **`./logs/`** 目錄下，且已加入 `.gitignore`：

- **`logs/create_log.log`**: 記錄 `batch_gh_create.ps1` 的執行結果。
- **`logs/git_remote_list.log`**: 記錄掃描到的標準遠端位址清單。
- **`logs/excluded_projects.log`**: 紀錄 `batch_git_remote.ps1` 略過專案的詳細原因。
- **`logs/git_remote_debug.log`**: 記錄擁有多重遠端位址的專案。
- **`out/extracted_projects.txt`**: 導出的可用專案清單，格式符合 `projects.txt`。
- **`logs/git_pull_errors.log`**: 記錄更新失敗的倉庫。
- **`logs/git_status_changed.log`**: 記錄偵測到異動的檔案清單與專案描述。

> 💡 **提示**：所有 Log 與導出檔案在每次對應的腳本啟動時，都會自動清空舊資料。

---

## 📄 檔案結構
- `batch_gh_create.ps1`: 核心建立與同步工具。
- `batch_git_pull.ps1`: 批次更新工具。
- `batch_create_git_sync.ps1`: 批次同步腳本初始化工具。
- `batch_git_status.ps1`: 批次異動檢查工具。
- `batch_git_remote.ps1`: 批次遠端位址掃描工具。
- `ini/accounts.txt.example`: 帳號清單範本。
- `ini/projects.txt.example`: 專案清單範本。
- `.env.example`: 環境變數範本。


