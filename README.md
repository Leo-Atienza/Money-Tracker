# Expense Tracker

A comprehensive personal finance application built with Flutter, designed to help users track spending, manage budgets, and analyze financial habits with ease.

## 🌟 Key Features

*   **Dashboard:** Real-time overview of your financial health.
*   **Transaction Tracking:** Easily add expenses and income.
*   **Recurring Transactions:** Automate bills and salary entries.
*   **Budgeting:** Set monthly limits per category and get alerted.
*   **Analytics:** Visual charts to understand spending patterns.
*   **Multiple Accounts:** Manage personal and business finances separately.
*   **Data Safety:** Local backup/restore and CSV export.
*   **Dark Mode:** Comfortable viewing at night.

## 📱 User Guide

For a detailed user manual and technical documentation, please refer to [DOCUMENTATION.md](DOCUMENTATION.md).

## 🛠️ Technical Stack

*   **Framework:** Flutter
*   **Language:** Dart
*   **State Management:** Provider
*   **Database:** Sqflite (SQLite)
*   **Charts:** fl_chart
*   **Notifications:** flutter_local_notifications

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (3.0.0 or higher)
*   Android Studio / VS Code
*   Android Emulator or Physical Device

### Installation

1.  **Clone the repository**
    ```bash
    git clone https://github.com/yourusername/budget_tracker.git
    cd budget_tracker
    ```

2.  **Install dependencies**
    ```bash
    flutter pub get
    ```

3.  **Run the app**
    ```bash
    flutter run
    ```

## 📂 Project Structure

*   `lib/models`: Data models for Database and UI.
*   `lib/screens`: UI Screens (Home, History, Settings, etc.).
*   `lib/providers`: State management logic (`AppState`).
*   `lib/database`: SQLite database helper.
*   `lib/utils`: Helpers for currency, dates, notifications, and backups.
*   `lib/widgets`: Reusable UI components.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
