# 快速修复指南

## ✅ 已修复的问题

### 问题 1: 数据库配置不匹配（已修复）

**修复内容：**
- 修改 `application.yml` 中的数据库配置，使其与 docker-compose 一致
- 端口: `55433` → `55434`
- 数据库: `talent_archive` → `resume_blueprint_db`
- 用户: `archive_user` → `rb_user`
- 密码: `archive_pass` → `rb_password`

**验证方法：**
```powershell
# 1. 确保数据库容器运行
cd talent-archive-core
docker compose ps
# 应该看到 resume_blueprint_postgres 在运行，端口映射 0.0.0.0:55434->5432/tcp

# 2. 测试数据库连接
docker compose exec postgres psql -U rb_user -d resume_blueprint_db -c "SELECT 1;"
# 应该返回 1 行结果

# 3. 启动后端并检查日志
cd ..\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
# 查看启动日志，应该看到 Flyway 迁移成功，没有连接错误
```

---

## 🔍 验证修复是否生效

### 快速验证命令（按顺序执行）

#### 1. 检查 Docker 容器状态
```powershell
cd talent-archive-core
docker compose ps
```

**预期输出：**
```
NAME                        IMAGE               STATUS          PORTS
resume_blueprint_postgres   postgres:16         Up X minutes    0.0.0.0:55434->5432/tcp
```

#### 2. 检查数据库是否可访问
```powershell
docker compose exec postgres psql -U rb_user -d resume_blueprint_db -c "\dt"
```

**预期输出：** 应该列出数据库中的表（rb_document, rb_run 等）

#### 3. 启动后端应用
```powershell
cd ..\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

**查看日志关键信息：**
- ✅ `Started ResumeBlueprintApiApplication` - 应用启动成功
- ✅ `Flyway migration successful` 或类似信息 - 数据库迁移成功
- ❌ `Connection refused` - 连接失败（需要检查端口）
- ❌ `password authentication failed` - 用户/密码错误
- ❌ `database does not exist` - 数据库不存在

#### 4. 健康检查（新开一个 PowerShell 窗口）
```powershell
Invoke-WebRequest -Uri "http://localhost:18080/api/extract/health" -UseBasicParsing
```

**预期输出：**
```
StatusCode        : 200
Content           : {"runId":0,"message":"Extraction service is available"}
```

#### 5. 运行完整 E2E 测试
```powershell
cd <项目根目录>
.\requests\e2e_smoke.ps1
```

**预期输出：**
- Health Check: PASS
- Resume Ingestion: PASS
- Extract Service: PASS 或 WARN（取决于 extract-service 是否启动）
- Match Service: PASS 或 WARN（取决于是否有成功画像数据）

---

## 🐛 如果还有问题

### 问题 A: 后端启动时仍然报数据库连接错误

**可能原因：**
1. Docker 容器未启动
2. 端口仍然被占用
3. 数据库名/用户/密码仍然不匹配

**排查步骤：**
```powershell
# 1. 检查容器是否真的在运行
docker ps | findstr resume_blueprint_postgres

# 2. 检查端口占用
netstat -ano | findstr :55434
# 如果被占用，查看是哪个进程（最后一列是 PID），然后 kill 它

# 3. 检查应用配置是否真的改了
type resume-blueprint\resume-blueprint-api\src\main\resources\application.yml
# 确认 datasource.url 是 jdbc:postgresql://127.0.0.1:55434/resume_blueprint_db

# 4. 手动测试数据库连接
docker compose exec postgres psql -U rb_user -d resume_blueprint_db
# 如果成功，会进入 psql 提示符，输入 \q 退出
```

### 问题 B: Flyway 迁移失败

**可能原因：**
1. 数据库中没有迁移表
2. 迁移脚本有语法错误

**排查步骤：**
```powershell
# 查看 Flyway 状态
docker compose exec postgres psql -U rb_user -d resume_blueprint_db -c "SELECT * FROM flyway_schema_history;"

# 如果表不存在，Flyway 会自动创建
# 如果迁移失败，查看应用启动日志的具体错误信息
```

### 问题 C: Extract Service 不可用（WARN）

**这不是致命错误，但如果想修复：**

```powershell
# 启动 extract-service
cd talent-archive-core
docker compose up -d extract-service

# 等待 40 秒让服务完全启动
Start-Sleep -Seconds 40

# 验证服务
Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing
# 应该返回 {"status":"ok","models_loaded":true}
```

---

## 📋 完整启动流程（修复后）

```powershell
# 1. 启动数据库
cd talent-archive-core
docker compose up -d postgres

# 2. 等待数据库就绪（5秒）
Start-Sleep -Seconds 5

# 3. 启动后端应用（在新窗口或后台）
cd ..\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run

# 4. 等待应用启动（约10-20秒）
Start-Sleep -Seconds 20

# 5. 验证健康检查
Invoke-WebRequest -Uri "http://localhost:18080/api/extract/health" -UseBasicParsing

# 6. 运行 E2E 测试
cd ..\..
.\requests\e2e_smoke.ps1
```

---

## ✅ 修复验证清单

- [ ] Docker 容器 `resume_blueprint_postgres` 运行中
- [ ] 端口映射正确：`55434:5432`
- [ ] 数据库 `resume_blueprint_db` 存在且可访问
- [ ] 用户 `rb_user` 可以连接数据库
- [ ] 应用启动无数据库连接错误
- [ ] Flyway 迁移成功
- [ ] 健康检查返回 200
- [ ] E2E 测试通过（至少 Health Check 和 Resume Ingestion）

---

**最后更新：** 2024-01-01  
**修复版本：** v1.0
