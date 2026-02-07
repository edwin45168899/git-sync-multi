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

# 設定搜尋的根目錄 (優先從環境變數取得)
$rootPath = if ($env:ROOT_PATH) { $env:ROOT_PATH } else { "D:\github\chiisen\" }
$logPath = Join-Path $PSScriptRoot "git_pull_errors.log"

Write-Host "開始批次執行 git pull: $rootPath ..." -ForegroundColor Cyan

# 清空之前的 Log
"" | Out-File -FilePath $logPath -Encoding utf8

# 取得所有子目錄
$directories = Get-ChildItem -Path $rootPath -Directory

foreach ($dir in $directories) {
    $gitDir = Join-Path $dir.FullName ".git"
    
    # 檢查是否為 Git 倉庫
    if (Test-Path $gitDir) {
        Write-Host "正在處理: $($dir.Name)..." -ForegroundColor Gray
        
        # 執行 git pull
        # 使用 -C 參數可以直接指定路徑執行的 git 指令
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
    else {
        Write-Host "跳過 (非 Git 倉庫): $($dir.Name)" -ForegroundColor DarkGray
    }
}

Write-Host "`n全部處理完成！" -ForegroundColor Cyan
if (Test-Path $logPath) {
    $errorCount = (Get-Content $logPath | Measure-Object -Line).Lines
    if ($errorCount -gt 1) {
        Write-Host "有 $errorCount 處錯誤，請查看 Log: $logPath" -ForegroundColor Yellow
    }
}
