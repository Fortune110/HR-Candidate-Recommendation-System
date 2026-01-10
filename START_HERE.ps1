# 一键启动脚本 - 修复后的完整流程
# 在 PowerShell 中执行: .\START_HERE.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  HR Candidate Recommendation System" -ForegroundColor Cyan
Write-Host "  快速启动脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查当前目录
$projectRoot = $PSScriptRoot
if (-not $projectRoot) {
    $projectRoot = Get-Location
}

Write-Host "项目根目录: $projectRoot" -ForegroundColor Yellow
Write-Host ""

# 步骤1: 启动数据库
Write-Host "[1/4] 启动 PostgreSQL 数据库..." -ForegroundColor Green
Push-Location "$projectRoot\talent-archive-core"
docker compose up -d postgres
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: 无法启动数据库容器" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "✓ 数据库容器已启动" -ForegroundColor Green
Pop-Location

# 等待数据库就绪
Write-Host ""
Write-Host "[2/4] 等待数据库就绪（5秒）..." -ForegroundColor Green
Start-Sleep -Seconds 5

# 步骤2: 验证数据库连接
Write-Host ""
Write-Host "[3/4] 验证数据库连接..." -ForegroundColor Green
Push-Location "$projectRoot\talent-archive-core"
$dbCheck = docker compose exec -T postgres psql -U rb_user -d resume_blueprint_db -c "SELECT 1;" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ 数据库连接正常" -ForegroundColor Green
} else {
    Write-Host "警告: 数据库连接可能有问题，但继续执行..." -ForegroundColor Yellow
    Write-Host "  错误信息: $dbCheck" -ForegroundColor Yellow
}
Pop-Location

# 步骤3: 启动后端应用
Write-Host ""
Write-Host "[4/4] 启动 Spring Boot 应用..." -ForegroundColor Green
Write-Host "  应用将在后台启动，请查看新窗口的输出" -ForegroundColor Yellow
Write-Host "  或者等待 20 秒后运行健康检查" -ForegroundColor Yellow
Write-Host ""

Push-Location "$projectRoot\resume-blueprint\resume-blueprint-api"

# 检查是否已经运行
$existingProcess = Get-Process -Name java -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*ResumeBlueprintApiApplication*"
} -ErrorAction SilentlyContinue

if ($existingProcess) {
    Write-Host "  检测到应用可能已在运行，跳过启动" -ForegroundColor Yellow
    Write-Host "  如果健康检查失败，请手动启动: .\mvnw.cmd spring-boot:run" -ForegroundColor Yellow
} else {
    Write-Host "  启动命令: .\mvnw.cmd spring-boot:run" -ForegroundColor Cyan
    Write-Host "  提示: 请在新窗口运行此命令，或使用以下命令在后台启动:" -ForegroundColor Cyan
    Write-Host "    Start-Process powershell -ArgumentList '-NoExit', '-Command', 'cd $projectRoot\resume-blueprint\resume-blueprint-api; .\mvnw.cmd spring-boot:run'" -ForegroundColor Cyan
}

Pop-Location

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  下一步操作" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. 如果应用未自动启动，请在新窗口运行:" -ForegroundColor Yellow
Write-Host "   cd $projectRoot\resume-blueprint\resume-blueprint-api" -ForegroundColor White
Write-Host "   .\mvnw.cmd spring-boot:run" -ForegroundColor White
Write-Host ""
Write-Host "2. 等待 20 秒后，运行健康检查:" -ForegroundColor Yellow
Write-Host "   Invoke-WebRequest -Uri 'http://localhost:18080/api/extract/health' -UseBasicParsing" -ForegroundColor White
Write-Host ""
Write-Host "3. 如果健康检查返回 200，运行 E2E 测试:" -ForegroundColor Yellow
Write-Host "   cd $projectRoot" -ForegroundColor White
Write-Host "   .\requests\e2e_smoke.ps1" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
