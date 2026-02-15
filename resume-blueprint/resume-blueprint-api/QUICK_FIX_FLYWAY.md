# Flyway Fix - 100% Executable Version (Fixed Pitfalls)

## ✅ Fixed Issues

1. **Pitfall 1 Fixed**: Don't hardcode container name, dynamically find Postgres container
2. **Pitfall 2 Fixed**: Don't use `-it` parameter in PowerShell scripts (non-interactive environment)

## 🚀 Quick Fix (3 Steps)

### Step 1: Find Postgres Container and Reset Database

```powershell
# Automatically find Postgres container name
$pg = (docker ps --format "{{.Names}} {{.Image}}" | Select-String "postgres" | ForEach-Object { $_.ToString().Split(" ")[0] } | Select-Object -First 1)
Write-Host "Postgres container: $pg"

# Reset database (Note: Don't use -it parameter)
docker exec $pg psql -U rb_user -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;"
docker exec $pg psql -U rb_user -d postgres -c "CREATE DATABASE resume_blueprint_db OWNER rb_user;"

# If above reports "role rb_user does not exist", use postgres user:
# docker exec $pg psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;"
# docker exec $pg psql -U postgres -d postgres -c "CREATE DATABASE resume_blueprint_db;"
```

### Step 2: Start Backend

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

**Wait to see**:
```
Successfully applied X migration(s)
Started ResumeBlueprintApiApplication in X.XXX seconds
```

### Step 3: Verify (Open New PowerShell Window)

```powershell
# Check port
netstat -ano | findstr :18080

# Test pages (should return 200)
curl -I http://localhost:18080/upload
curl -I http://localhost:18080/swagger-ui/index.html
```

## 📝 One-Click Fix Script

Created `FIX_FLYWAY.ps1`, run directly:

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\FIX_FLYWAY.ps1
```

The script will automatically:
- ✅ Stop backend (if running)
- ✅ Dynamically find Postgres container name
- ✅ Reset database (automatically handle rb_user not existing)
- ✅ Verify database connection
- ✅ Prompt next steps

## 🔍 Common Error Handling

### Error 1: Cannot Find Postgres Container

```
✗ Error: Cannot find Postgres container
```

**Solution**:
```powershell
# View all containers
docker ps -a

# If container not running, start it (first find docker-compose.yml location)
Get-ChildItem -Recurse -Filter "docker-compose.yml" | Select-Object DirectoryName
# Then go to that directory and execute: docker-compose up -d postgres
```

### Error 2: role rb_user does not exist

**Solution**: Use postgres superuser (script will handle automatically)

### Error 3: Port Already in Use

```powershell
# Find process using port
netstat -ano | findstr :18080 | findstr LISTENING

# Terminate process (assuming PID is 12345)
Stop-Process -Id 12345 -Force
```

## ✅ Verification Checklist

After fix completion, confirm:
- [ ] Database reset (`\dt` shows empty, or only flyway_schema_history)
- [ ] Backend startup successful (see `Started ResumeBlueprintApiApplication`)
- [ ] Flyway migrations executed successfully (see `Successfully applied X migration(s)`)
- [ ] Port 18080 listening
- [ ] `http://localhost:18080/upload` returns 200
- [ ] `http://localhost:18080/swagger-ui/index.html` returns 200
