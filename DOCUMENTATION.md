# Expense Tracker - Application Documentation

**Version:** 4.0.0  
**Author:** Leo Atienza  
**Framework:** Flutter  

---

## 1. Introduction

**Expense Tracker** is a personal finance application designed to help users track their daily spending, manage monthly budgets, and analyze financial habits. The app supports multiple accounts (e.g., Personal, Business), insightful statistics, and a clean, user-friendly interface with Dark Mode support.

---

## 2. Key Features

*   **Dashboard Overview:** Instant view of remaining budget, total spent, and budget progress.
*   **Expense & Income Tracking:** Add expenses and income with categories, amounts, dates, and optional descriptions.
*   **Recurring Transactions:** Automate monthly bills and salary deposits with customizable recurring rules.
*   **Quick Templates:** Create 1-tap templates for frequent transactions (e.g., "Morning Coffee").
*   **Edit & Delete:** Modify or remove existing transactions easily.
*   **Trash:** Deleted items are moved to Trash for 30 days before permanent deletion, allowing recovery.
*   **Multiple Accounts:** Manage separate finances for different purposes (e.g., "Personal", "Work") within a single app.
*   **Budget Management:** Set monthly spending limits per category.
*   **History View:** Browse transactions by month with daily breakdowns.
*   **Advanced Statistics:** Visualize spending with Analytics charts and insights.
*   **Dark Mode:** Built-in support for light and dark themes.
*   **Local Storage & Backup:** Data is securely stored on the device using SQLite, with backup/restore functionality.
*   **Notifications:** Bill reminders, budget alerts, and monthly summaries.
*   **Export:** Export data to CSV for external analysis.

---

## 3. User Guide

### 3.1 Getting Started
Upon launching the app, you will start with a default "Main Account". You can begin adding transactions immediately or go to Settings to customize your account name and currency.

### 3.2 Home Screen
The Home Screen provides a quick snapshot of your finances:
*   **Summary Cards:** Shows Total Income, Total Expense, Balance, and Paid/Pending amounts.
*   **Recent Transactions:** A list of the most recent transactions.
*   **Floating Action Button:** Quickly add new Expenses or Income.

### 3.3 Adding & Managing Transactions
*   **Add Transaction:** Tap the **+** button on the Home screen.
    *   Choose **Expense** or **Income**.
    *   Enter Amount.
    *   Select a Category (Food, Transport, Salary, etc.).
    *   (Optional) Enter a Description, Date, and Payment Method.
    *   Tap **Save**.
*   **Quick Templates:** In Settings > Quick Templates, create templates for frequent items.
*   **Edit Transaction:** Tap on any transaction in the History list to edit details.
*   **Delete Transaction:** Swipe left or long-press to delete. Deleted items go to **Trash** (Settings > Trash) where they can be restored or permanently deleted.

### 3.4 Recurring Transactions
*   Navigate to **Settings > Recurring Expenses** or **Recurring Income**.
*   Add a new recurring item with Amount, Category, and Day of Month.
*   The app will automatically create the transaction when the day arrives.
*   **Bill Reminders:** Receive notifications before bills are due.

### 3.5 History & Analytics
*   **History Tab:** Browse all past transactions by month. Use arrows to navigate between months.
*   **Analytics Tab:** Visualize spending patterns with charts.
    *   *Spending by Category*: See where your money goes.
    *   *Monthly Trends*: Compare spending over time.

### 3.6 Settings & Customization
Navigate to the **Settings** screen (Gear icon) to manage:

#### Accounts
*   **Switch Accounts:** Toggle between different financial accounts (e.g., Personal vs Business).
*   **Add Account:** Create new accounts to keep finances separate.

#### Appearance & Preferences
*   **Dark Mode:** Toggle between Light and Dark themes.
*   **Currency:** Select your preferred currency symbol.
*   **Categories:** Add, edit, or delete custom categories.

#### Data Management
*   **Backup & Restore:** Create local backups of your data or restore from a previous file.
*   **Export to CSV:** Export your transaction history for use in Excel or other tools.
*   **Trash:** View and restore deleted items.

#### Notifications
*   **Bill Reminders:** Toggle reminders for recurring expenses.
*   **Budget Alerts:** Get notified when you approach your budget limits.
*   **Monthly Summary:** Receive a monthly report of your financial status.

---

## 4. Technical Overview

This application is built using **Flutter** and follows a robust architecture for maintainability and scalability.

### 4.1 Architecture
*   **State Management:** The app uses the **Provider** pattern (`ChangeNotifier`) to manage application state (`AppState`). This ensures UI components update reactively when data changes.
*   **Database:** Uses `sqflite` for persistent local storage.
    *   **Tables:** `accounts`, `expenses`, `income`, `budgets`, `categories`, `quick_templates`, `recurring_expenses`, `recurring_income`, `tags`.
    *   **Relationships:** Transactions are linked to Accounts and Categories via Foreign Keys.

### 4.2 Key Libraries
*   `provider`: State management.
*   `sqflite`: SQLite database plugin for Flutter.
*   `path_provider`: Access filesystem for backups.
*   `intl`: Date and number formatting.
*   `fl_chart`: Rendering charts in Analytics.
*   `flutter_local_notifications`: Local notifications for reminders.
*   `share_plus`: Sharing backup files and exports.

### 4.3 Data Models
*   **Expense/Income:** `id`, `amount`, `category`, `description`, `date`, `accountId`, `paymentMethod`.
*   **RecurringTransaction:** `id`, `amount`, `category`, `dayOfMonth`, `isActive`, `lastCreated`.
*   **Budget:** `id`, `amount`, `category`, `month`, `accountId`.
*   **Account:** `id`, `name`, `isDefault`.

---
*Built by Leo Atienza*
