# git-sync-multi
批次管理多個 Git 專案的同步與備份工具。

## 🚀 功能：batch_git_pull.ps1
此腳本會自動掃描指定目錄下的所有子資料夾，若發現為 Git 倉庫，則自動執行 `git pull` 以同步遠端更新。

### 使用方法
1. **設定環境變數**：
   - 複製 `.env.example` 並更名為 `.env`。
   - 在 `.env` 中修改 `ROOT_PATH` 為你存放所有 Git 專案的根目錄。
2. **執行腳本**：
   - 在 PowerShell 中執行：
     ```powershell
     ./batch_git_pull.ps1
     ```

### 環境配置 (.env)
| 變數名稱 | 說明 | 範例 |
| :--- | :--- | :--- |
| `ROOT_PATH` | 所有 Git 專案的父目錄路徑 | `D:\github\chiisen\` |

### 錯誤記錄
若執行過程中發生錯誤，將會記錄在 `git_pull_errors.log` 中。
