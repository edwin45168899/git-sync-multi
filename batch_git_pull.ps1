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
$logDir = Join-Path $PSScriptRoot "logs"
$logPath = Join-Path $logDir "git_pull_errors.log"

# 確保 Log 資料夾存在
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

Write-Host "開始批次執行 git pull: $rootPath ..." -ForegroundColor Cyan

# 清空之前的 Log
"" | Out-File -FilePath $logPath -Encoding utf8

# 取得所有子目錄
$directories = Get-ChildItem -Path $rootPath -Directory

$currentCount = 0
# 預先計算合法的 Git 倉庫數量
$validRepos = $directories | Where-Object { Test-Path (Join-Path $_.FullName ".git") }
$totalRepoCount = if ($null -ne $validRepos) { $validRepos.Count } else { 0 }

Write-Host "偵測到 $totalRepoCount 個 Git 倉庫，開始平行更新 (加速模式)..." -ForegroundColor Cyan

$executionTime = Measure-Command {
    $directories | ForEach-Object -Parallel {
        $dir = $_
        $gitDir = Join-Path $dir.FullName ".git"
        $logPath = $using:logPath
        
        if (Test-Path $gitDir) {
            # 執行 git pull
            $output = git -C $dir.FullName pull 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                $errorMsg = "❌ [錯誤] 目錄: $($dir.FullName)`n原因: $output`n"
                Write-Host $errorMsg -ForegroundColor Red
                $errorMsg | Out-File -FilePath $logPath -Append -Encoding utf8
            }
            else {
                Write-Host "✅ [成功] $($dir.Name)" -ForegroundColor Green
            }
        }
    } -ThrottleLimit 10
}

$minutes = [Math]::Floor($executionTime.TotalMinutes)
$seconds = $executionTime.Seconds
Write-Host "`n全部處理完成！" -ForegroundColor Cyan
Write-Host "總計耗時: $minutes 分 $seconds 秒" -ForegroundColor Yellow

if (Test-Path $logPath) {
    $errorCount = (Get-Content $logPath | Where-Object { $_.Trim() -ne "" } | Measure-Object -Line).Lines
    if ($errorCount -gt 1) {
        Write-Host "有發現錯誤紀錄，請查看 Log: $logPath" -ForegroundColor Red
    }
}
