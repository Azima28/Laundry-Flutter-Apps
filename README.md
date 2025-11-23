# Laundry App (Flutter)

A lightweight demo Flutter app for a small laundry business: service listings, order creation, order history, and local storage. This repository is prepared so others can clone, run, and adapt the app quickly.

Key features: Flutter UI, `sqflite` local storage, `shared_preferences` for small persistent values.

---
## Setup Preview

![Setup Screenshot](images/setup.png)

## Requirements

- Flutter SDK (stable channel recommended)
- Android SDK / Android Studio (for Android development and builds)
- Optional: Xcode and macOS (for iOS builds)

Verify your environment (PowerShell):

```powershell
flutter --version
flutter doctor
```

Note: `pubspec.yaml` specifies Dart `^3.9.2`.

---

---

## Project layout (top-level)

- `lib/` — Dart source code
  - `screen/` — UI screens (login, dashboard, orders, history, etc.)
  - `database/` — local DB helper (`DatabaseHelper`) and model classes
  - `transactions/` — repository code for data access
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` — platform folders

---

## Analysis & tests

Run static analysis and tests:

```powershell
flutter analyze
flutter test
```

Resolve analyzer issues before making important commits.

---

## Troubleshooting

- If `flutter` is not recognized in PowerShell, add the SDK `bin` to your PATH temporarily:

```powershell
$env:PATH = "$env:PATH;C:\path\to\flutter\bin"
flutter --version
```

- To add Flutter to your user PATH permanently, update your Windows user environment variables or use a PowerShell snippet to append it.

---

## Data privacy

This app stores local data using `sqflite` and `shared_preferences`. Review `lib/database/` and any sample data before publishing data publicly.

---

## Publish to GitHub (example)

Create a repository on GitHub and push the project:

```powershell
git init
git add .
git commit -m "Prepare project for public sharing: update README"
git branch -M main
git remote add origin https://github.com/<username>/<repo>.git
git push -u origin main
```

Replace the remote URL with your repository URL.

---

## License

This project includes an MIT `LICENSE` file in the repository root. Update the owner information if needed.

---

## Contact

For questions or feedback, reach out:

- Email: `azimarizki2@gmail.com`
- Instagram: `@zimm.def`
- WhatsApp: `+6289522584477`

If you want, I can run the `git` commands to commit and push this change for you (I will need the repository remote already configured). Tell me to proceed if you'd like that.

