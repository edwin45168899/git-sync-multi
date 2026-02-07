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
        $status = git -C $dir.FullName status --porcelain 2>$null
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
                $msg = "📍 [有異動] $($dir.Name)"
                Write-Host $msg -ForegroundColor Yellow
                
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

