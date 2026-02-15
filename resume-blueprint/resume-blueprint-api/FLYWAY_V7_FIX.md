# Flyway V7 Migration Fix Explanation

## 📋 Problem Analysis

### Tables Referenced by V7

**V7__ml_training_view.sql** references the following tables:

1. ✅ `rb_candidate` - Created in **V5**
2. ✅ `rb_candidate_stage_history` - Created in **V5**
3. ❌ `rb_document` - Created in **V10** (does not exist when V7 executes)
4. ❌ `rb_match_run` - Created in **V13** (does not exist when V7 executes)
5. ❌ `rb_match_result` - Created in **V13** (does not exist when V7 executes)

### Execution Order Problem

**Current execution order**:
```
V1 → V2 → V5 → V6 → V7 ❌ → V10 → V11 → V12 → V13
```

**Problem**: V7 executes before V10 and V13, but needs these tables.

---

## ✅ Fix Solution (Implemented)

### Solution: Rename V7 to V14

**Reason**:
- V7 is a **VIEW** (not a table)
- VIEWs must be created after dependent tables are created
- Simplest way is to adjust execution order, let V7 execute after V13

**Operation**:
```powershell
# Executed: Renamed V7__ml_training_view.sql to V14__ml_training_view.sql
Move-Item V7__ml_training_view.sql V14__ml_training_view.sql
```

**New execution order**:
```
V1 → V2 → V5 → V6 → V10 → V11 → V12 → V13 → V14 ✅
```

When V14 executes, all dependent tables exist:
- ✅ `rb_document` (V10)
- ✅ `rb_match_run` (V13)
- ✅ `rb_match_result` (V13)
- ✅ `rb_candidate` (V5)
- ✅ `rb_candidate_stage_history` (V5)

---

## 🔍 Why Not Use Solution A (Create V3/V4)?

**Problems with Solution A**:
1. If creating V3 to create `rb_document`, `rb_match_run`, `rb_match_result`:
   - V10 would try to create `rb_document` again (although using `if not exists` won't fail, it's redundant)
   - V13 would try to create `rb_match_run`, `rb_match_result` again (redundant)
2. High maintenance cost: Same table defined in two places, easy to become inconsistent
3. V7 is a VIEW, not a table, adjusting VIEW execution order is more reasonable

**Conclusion**: Renaming V7 to V14 is the most concise and correct solution.

---

## 🚀 Verification Steps (Copy and Execute)

### Step 1: Reset Database

```powershell
# Find Postgres container
$pg = (docker ps --format "{{.Names}} {{.Image}}" | Select-String "postgres" | ForEach-Object { $_.ToString().Split(" ")[0] } | Select-Object -First 1)

# Reset database
docker exec $pg psql -U rb_user -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;"
docker exec $pg psql -U rb_user -d postgres -c "CREATE DATABASE resume_blueprint_db OWNER rb_user;"
```

### Step 2: Start Backend

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

### Step 3: Verify Migrations

**Expected logs**:
```
Successfully validated 9 migrations
Migrating schema "public" to version "1 - blueprint core"
Migrating schema "public" to version "2 - baseline"
Migrating schema "public" to version "5 - candidate pipeline stage"
Migrating schema "public" to version "6 - candidate stage history reason code"
Migrating schema "public" to version "10 - rb core"
Migrating schema "public" to version "11 - rb baseline"
Migrating schema "public" to version "12 - rb review"
Migrating schema "public" to version "13 - success profile and match"
Migrating schema "public" to version "14 - ml training view"  ✅
Successfully applied 9 migration(s)
Started ResumeBlueprintApiApplication
```

### Step 4: Verify Page Access

**Execute in new PowerShell window**:

```powershell
# Check port
netstat -ano | findstr :18080 | findstr LISTENING

# Test upload page
curl -I http://localhost:18080/upload

# Test Swagger UI
curl -I http://localhost:18080/swagger-ui/index.html
```

**Expected results**:
- Port 18080 listening
- `/upload` returns `200 OK` or `302 Found`
- `/swagger-ui/index.html` returns `200 OK`

---

## ✅ Verification Checklist

After fix completion, confirm:
- [ ] Database reset (empty database)
- [ ] All 9 migrations executed successfully (V1, V2, V5, V6, V10, V11, V12, V13, V14)
- [ ] Backend startup successful (see `Started ResumeBlueprintApiApplication`)
- [ ] Port 18080 listening
- [ ] `http://localhost:18080/upload` accessible
- [ ] `http://localhost:18080/swagger-ui/index.html` accessible
- [ ] `ml_training_examples_v1` view created (optional verification)

---

## 📝 Follow-up Recommendations

1. **Migration Naming Convention**: VIEWs should be after dependent tables are created
2. **Dependency Check**: Before creating a VIEW, ensure all dependent tables exist
3. **Testing Strategy**: After each new migration, reset database and test complete migration flow
