# Contributing

Thank you for wanting to contribute! This short guide will help you get set up and make high-quality contributions that are easy to review.

Workflow
1. Fork the repository and create a feature branch:

```powershell
 git checkout -b feature/short-description
```

2. Install dependencies and run static checks locally before committing:

```powershell
 flutter pub get
 flutter analyze
 flutter test
```

3. Keep commits small and focused. Use clear commit messages like:

```
 feat: add item list screen
 fix: correct null-check in order flow
 docs: update README
```

4. Open a Pull Request describing the change, why it matters, and any testing notes.

Branch naming and PRs
- Use `feature/`, `fix/`, or `chore/` prefixes for branches.
- Reference related issues in the PR description when applicable.

PATH setup (Windows)

If you need to add Flutter to your PATH, these PowerShell snippets help. Adjust the path to match where your SDK is installed.

Temporary (current PowerShell session only):

```powershell
 $env:PATH = "$env:PATH;C:\Work\project apps\flutter\flutter\bin"
```

Persistent (adds to User PATH): run once in PowerShell (change the path if yours differs):

```powershell
 $old = [Environment]::GetEnvironmentVariable('Path','User')
 if ($old -notlike '*C:\Work\project apps\flutter\\flutter\\bin*') {
   $new = $old + ';C:\Work\project apps\flutter\flutter\bin'
   [Environment]::SetEnvironmentVariable('Path',$new,'User')
 }
```

Notes
- Restart your terminal or VS Code after updating the User PATH.
- Run `flutter doctor` to check the full environment.

Code review checklist
- Runs `flutter analyze` with no new issues
- Unit/widget tests pass locally
- No large unrelated changes included in the PR

Thanks — we appreciate any improvements, bug fixes, or documentation updates!

