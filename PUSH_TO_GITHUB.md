# Push to GitHub

The following has been done locally:

1. **Branch**: Created branch `push-candidate` from the current state.
2. **Commit**: All changes (69 files) committed; message summarizes candidate stage management, ML training export, Flyway reorder, and docs.
3. **.gitignore**: Added `__pycache__/`, `*.pyc`, `*.pyo`; removed tracked `ml/__pycache__` from the repo.

Run the push from **PowerShell or Git Bash** on your machine (GitHub access required):

```powershell
cd c:\HR-Candidate-Recommendation-System
git push origin push-candidate
```

To update the `main` branch on GitHub as well:

```powershell
git checkout main
git merge push-candidate
git push origin main
```

If SSH fails (e.g. `bad line length character`), switch to HTTPS and push:

```powershell
git remote set-url origin https://github.com/Fortune110/HR-Candidate-Recommendation-System.git
git push origin push-candidate
```

Remote URL: `git@github.com:Fortune110/HR-Candidate-Recommendation-System.git`
