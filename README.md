# 💳 SG → Notion

A macOS Flutter app to import **Société Générale** bank statements (CSV) into a **Notion** database.

## ✨ Features

- 📂 **CSV Import** — drag & drop or file picker
- 🏷️ **Expense review** — rename, categorize, set payment method
- 🤖 **Auto-suggestions** — category suggested based on the label
- 🧠 **Merchant memory** — the app learns your category choices
- 🚀 **Export to Notion** — direct push via the Notion API
- 📊 **Analytics** — monthly and per-category charts pulled from Notion
- 🗂️ **Import history** — resume an in-progress import
- 🚫 **Ignore** — exclude specific expenses from export
- 🔍 **Filters** — All / To review / Reviewed / Sent / Ignored

## 🛠️ Stack

- [Flutter](https://flutter.dev) (macOS desktop)
- [Notion API](https://developers.notion.com)
- [fl_chart](https://pub.dev/packages/fl_chart) for charts

## 🚀 Getting started

### Prerequisites
- Flutter SDK (`flutter --version`)
- A Notion account with a database set up for expenses

### Run the app

```bash
git clone https://github.com/YOUR_USERNAME/track_expenses.git
cd track_expenses
flutter pub get
flutter run -d macos
```

## ⚙️ Notion setup

1. Create a [Notion integration](https://www.notion.so/my-integrations) and copy the token
2. Share your database with the integration
3. In the app → **Settings** → enter your token and database ID
4. Adjust column names if needed

### Expected Notion columns

| Column | Type |
|---|---|
| Expense *(or custom name)* | Title |
| Date | Date |
| Amount | Number |
| Category | Select |
| Payment method | Select |

## 📁 CSV format

Compatible with the standard Société Générale CSV export (`;` separator, Latin-1 encoding).

---

> ⚠️ This is a personal tool. The `settings.json` file (Notion token) is excluded from the repository via `.gitignore`.
