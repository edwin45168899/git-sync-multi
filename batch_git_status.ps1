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

# 設定搜尋的根目錄 (優先從環境變數取得)
$rootPath = if ($env:ROOT_PATH) { $env:ROOT_PATH } else { "D:\github\chiisen\" }
# 設定 Log 資訊
$logName = "git_status_changed.log"
$logDir = Join-Path $PSScriptRoot "logs"
$logPath = Join-Path $logDir $logName

# 確保 Log 資料夾存在
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$startTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$startMsg = "--- Git Status Check Start: $startTime ---`n掃描根目錄: $rootPath"

# 初始 Log (清空舊資料)
$null | Out-File -FilePath $logPath -Encoding utf8

Write-Host "開始檢查 git status (有異動的目錄): $rootPath ..." -ForegroundColor Cyan

# 記錄開始資訊到 Log
"$startMsg`n" | Out-File -FilePath $logPath -Encoding utf8

# 取得所有子目錄
$directories = Get-ChildItem -Path $rootPath -Directory

$changedCount = 0
$totalCount = 0

foreach ($dir in $directories) {
    $gitDir = Join-Path $dir.FullName ".git"
    
    # 檢查是否為 Git 倉庫
    if (Test-Path $gitDir) {
        $totalCount++
        # 執行 git status --porcelain
        $status = @(git -C $dir.FullName status --porcelain 2>$null | Where-Object { $_.Trim() -ne "" })
        
        if ($status.Count -eq 1 -and ($status[0] -match "setup_git_sync.ps1" -or $status[0] -match "\.python-version")) {
            # 💡 特殊處理：如果唯一的變更只有 setup_git_sync.ps1 或 .python-version，則捨棄變更
            $fileName = $status[0].Substring(3).Trim()
            Write-Host "🧹 [自動還原] 正在清理專案 $($dir.Name) 的雜訊檔案: $fileName" -ForegroundColor Gray
            
            # 1. 處理已追蹤的修改 (Modified)
            git -C $dir.FullName checkout -- $fileName 2>$null | Out-Null
            # 2. 處理未追蹤的檔案 (Untracked ??)
            git -C $dir.FullName clean -f $fileName 2>$null | Out-Null
            
            # 重新確認狀態
            $status = @(git -C $dir.FullName status --porcelain 2>$null | Where-Object { $_.Trim() -ne "" })
        }

        # 💡 特殊處理：如果異動只有 desktop.ini 或 folderico-green.ico，則自動 commit & pull
        if ($status.Count -gt 0) {
            $onlyIcons = $true
            foreach ($line in $status) {
                if ($line -notmatch "desktop\.ini" -and $line -notmatch "folderico-green\.ico") {
                    $onlyIcons = $false
                    break
                }
            }

            if ($onlyIcons) {
                Write-Host "🎨 [$($dir.Name)] 偵測到圖示設定異動，執行自動同步..." -ForegroundColor Cyan
                git -C $dir.FullName add desktop.ini folderico-green.ico 2>$null
                git -C $dir.FullName commit -m "feat: 更新目錄 icon" 2>$null
                git -C $dir.FullName pull 2>$null
                # 重新確認狀態
                $status = @(git -C $dir.FullName status --porcelain 2>$null | Where-Object { $_.Trim() -ne "" })
            }
        }

        if ($status) {
            # 嘗試取得 GitHub 描述與屬性 (Description, isFork, isPrivate)
            $description = "(無法取得描述)"
            $isFork = $false
            $isPrivate = $false
            $remotes = @(git -C $dir.FullName remote -v 2>$null | Where-Object { $_.Trim() -ne "" })
            $fetchLine = $remotes | Where-Object { $_ -match "\(fetch\)" }
            
            if ($fetchLine -match '[:/](?<owner>[^:/]+)/(?<repo>.+)\.git') {
                $repoFull = "$($Matches['owner'])/$($Matches['repo'])"
                $repoData = gh repo view $repoFull --json description,isFork,isPrivate 2>$null | ConvertFrom-Json
                if ($repoData) {
                    if ($repoData.description) { $description = $repoData.description }
                    if ($repoData.isFork) { $isFork = $repoData.isFork }
                    if ($repoData.isPrivate) { $isPrivate = $repoData.isPrivate }
                }
            }
            
            if ($isFork -or $isPrivate) {
                # Fork 或 Private 專案：僅記錄到 Log，不顯示在畫面上
                $label = if($isFork){ "FORK" } else { "PRIVATE" }
                "[$label 專案已跳過] [$($dir.Name)]`n說明: $description`n路徑: $($dir.FullName)`n內容:`n$($status -join "`n")`n" | Out-File -FilePath $logPath -Append -Encoding utf8
            } else {
                # 非 Fork 專案：顯示在畫面上並記錄到 Log
                $changedCount++
                $msg = "[$changedCount] 📍 [有異動] $($dir.Name)"
                Write-Host $msg -ForegroundColor Yellow
                
                # 顯示異動檔案清單 (縮排顯示)
                foreach ($line in $status) {
                    Write-Host "    $line" -ForegroundColor DarkGray
                }
                
                "[$($dir.Name)]`n說明: $description`n路徑: $($dir.FullName)`n內容:`n$($status -join "`n")`n" | Out-File -FilePath $logPath -Append -Encoding utf8
            }
        }
    }
}

$endTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$summaryMsg = "--- 檢查完成 ($endTime) ---`n總計掃描專案數: $totalCount`n有異動的專案數: $changedCount"

# 記錄結束總結到 Log
"`n$summaryMsg" | Out-File -FilePath $logPath -Append -Encoding utf8

Write-Host "`n$summaryMsg" -ForegroundColor Cyan
if ($changedCount -gt 0) {
    Write-Host "細節請查看 Log: $logPath" -ForegroundColor Yellow
} else {
    Write-Host "所有專案皆為乾淨狀態 (Clean)。" -ForegroundColor Green
}

