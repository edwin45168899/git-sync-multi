# 定義載入 .env 的函式
function Load-Env {
    param($Path = ".env")
    $envPath = Join-Path $PSScriptRoot $Path
    if (Test-Path $envPath) {
        Get-Content $envPath | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
            $parts = $_.Split('=', 2)
            if ($parts.Count -eq 2) {
                $name = $parts[0].Trim()
                $value = $parts[1].Trim().Trim('"').Trim("'")
                [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
            }
        }
    }
}

# 執行載入
Load-Env

# 切換 GitHub 帳號 (確保權限正確)
if ($env:GITHUB_ACCOUNT) {
    Write-Host "切換 GitHub 帳號至: $env:GITHUB_ACCOUNT" -ForegroundColor Cyan
    gh auth switch -u $env:GITHUB_ACCOUNT 2>$null
}
# 設定參數
$rootPath = if ($env:ROOT_PATH) { $env:ROOT_PATH } else { "D:\github\chiisen\" }
$logDir = Join-Path $PSScriptRoot "logs"
$excludedLogPath = Join-Path $logDir "excluded_sync_projects.log"
$templatePath = Join-Path $PSScriptRoot "temp\setup_git_sync.ps1.example"
$targetFileName = "setup_git_sync.ps1"

# 確保 Log 資料夾存在
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

# 初始 Log (清空舊資料)
"--- Excluded Sync Projects List ---`n" | Out-File -FilePath $excludedLogPath -Encoding utf8

# 讀取範本內容
if (-not (Test-Path $templatePath)) {
    Write-Error "找不到範本檔案: $templatePath"
    return
}
$templateContent = Get-Content -Path $templatePath -Raw

# 取得根目錄下的所有子目錄
$directories = Get-ChildItem -Path $rootPath -Directory

$totalCount = $directories.Count
Write-Host "偵測到 $totalCount 個目錄，開始平行建立腳本 (加速模式)..." -ForegroundColor Cyan

$executionTime = Measure-Command {
    # 使用管線收集平行處理產出的 Log 訊息
    $logBuffer = $directories | ForEach-Object -Parallel {
        $dir = $_
        $targetFileName = $using:targetFileName
        $targetPath = Join-Path $dir.FullName $targetFileName
        
        # --- 智慧過濾：跳過 Private 與 Fork 專案 ---
        $gitDir = Join-Path $dir.FullName ".git"
        if (Test-Path $gitDir) {
            # 解析遠端 URL 以取得 owner/repo
            $remoteUrl = git -C $dir.FullName remote get-url origin 2>$null
            if ($remoteUrl -match '[:/](?<owner>[^:/]+)/(?<repo>.+)\.git') {
                $owner = $Matches['owner']
                $repoName = $Matches['repo']
                $repoFull = "$owner/$repoName"

                # 透過 gh 檢查屬性 (包含描述)
                $repoData = gh repo view $repoFull --json isPrivate,isFork,description 2>$null | ConvertFrom-Json
                if ($null -ne $repoData) {
                    $isPrivate = $repoData.isPrivate
                    $isFork = $repoData.isFork
                    $desc = if ($repoData.description) { $repoData.description } else { "" }
                    $isDone = $desc.Trim().StartsWith("✅")

                    if ($isPrivate -or $isFork -or $isDone) {
                        $reason = if($isPrivate){"私有專案 (Private)"}elseif($isFork){"分支專案 (Fork)"}else{"標記為已完成 (✅)"}
                        Write-Host "跳過 ($reason): $($dir.Name)" -ForegroundColor DarkGray
                        
                        # 直接將 Log 內容傳回管線，由 $logBuffer 收集
                        "[$($dir.Name)] -- $reason"
                        return
                    }
                }
            }
        }

        # 如果該目錄已經有檔案，則跳過
        if (Test-Path $targetPath) {
            Write-Host "跳過 (`setup_git_sync.ps1` 檔案已存在): $($dir.Name)" -ForegroundColor Gray
            return
        }

        # 以子目錄名稱取代 PROJECT_NAME
        $projectName = $dir.Name
        $newContent = ($using:templateContent).Replace("PROJECT_NAME", $projectName)

        # 寫入新的檔案
        try {
            Set-Content -Path $targetPath -Value $newContent -Encoding utf8
            Write-Host "成功建立: $($dir.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "錯誤 (無法建立於 $($dir.Name)): $($_.Exception.Message)" -ForegroundColor Red
        }
    } -ThrottleLimit 10

    # 批次寫入記憶體中的 Log 緩衝區
    if ($logBuffer) {
        $logBuffer | Out-File -FilePath $excludedLogPath -Append -Encoding utf8
    }
}

$minutes = [Math]::Floor($executionTime.TotalMinutes)
$seconds = $executionTime.Seconds
Write-Host "`n批次處理完成！" -ForegroundColor Cyan
Write-Host "總計耗時: $minutes 分 $seconds 秒" -ForegroundColor Yellow
Write-Host "詳細排除名單請見: $excludedLogPath" -ForegroundColor Gray
