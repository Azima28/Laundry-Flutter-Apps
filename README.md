# Laundry App (Flutter)

A lightweight demo Flutter app for a small laundry business: service listings, order creation, order history, and local storage. This repository is prepared so others can clone, run, and adapt the app quickly.

Key features: Flutter UI, `sqflite` local storage, `shared_preferences` for small persistent values.

---
# Laundry App

A comprehensive Flutter-based laundry management application with separate interfaces for administrators and cashiers.

## Screenshots & Features

### Initial Setup

<p align="center">
  <img src="images/setup.png" width="350">
</p>

First, you register admin users to manage your application/admin. You are free to give any name and password.

---

### Admin Login

<p align="center">
  <img src="images/login.png" width="350">
</p>

Use your admin credentials to access the admin dashboard and manage the entire laundry system.

---

### Admin Dashboard

<p align="center">
  <img src="images/admin_dashboard.png" width="350">
</p>

The admin interface provides complete control over the laundry business operations:

- **User Management (Kelola User)**: Create and manage cashier accounts with username and password credentials
- **Laundry Item Management (Tambah Item Laundry)**: Add and configure laundry service items with pricing and stock settings
- **Dry Cleaning Management (Tambah Item Gosok)**: Manage dry cleaning/ironing services separately

---

### Add User Dialog

<p align="center">
  <img src="images/add_user.png" width="350">
</p>

Create new cashier accounts by providing username and password. Cashiers will use these credentials to access the order processing interface.

---

### Item Management

<p align="center">
  <img src="images/add_item.png" width="350">
</p>

Add and configure laundry service items:
- Enter item name (Nama Item)
- Set the price (Harga) in Rupiah
- Choose stock option:
  - Check "Stok Unlimited" for unlimited availability
  - Or enter a specific stock quantity in "Jumlah Stok"
- View and manage existing items with delete option

---

### Cashier Interface

<p align="center">
  <img src="images/cashier_home.png" width="350">
</p>

Clean welcome screen (Kasir Laundry) with quick access to main functions:
- **Pesan Laundry**: Create new laundry orders
- **Pesan Gosok**: Create dry cleaning orders
- **History Laundry**: View laundry service history
- **History Gosok**: View dry cleaning history

---

### Create New Order

<p align="center">
  <img src="images/order.png" width="350">
</p>

Process customer orders efficiently:
- Enter customer name (Nama Pemesan)
- Select items using the +/- buttons
- Real-time calculation of total items and price
- Available items shown with current prices

---

### Order History

<p align="center">
  <img src="images/history.png" width="350">
</p>

View all orders with comprehensive details:
- Search orders by name or item
- Order date and time
- Customer name
- Items and quantities
- Total price
- Payment status (Pending/Sudah Bayar)

---

## Getting Started

### Initial Setup

1. **Create Admin Account**
   - On first launch, you'll see the "Setup Admin Account" screen
   - Enter a username and password for the administrator
   - Click "Create Admin" to complete setup
   - This account will be used to access the admin dashboard

2. **Admin Login**
   - Use your admin credentials to log in
   - Access the Admin Dashboard to configure the application

### Configuring the Application

1. **Add Laundry Items**
   - Navigate to "Tambah Item Laundry" from the admin dashboard
   - Enter item name (e.g., "cuci kering", "cuci basah")
   - Set the price (Harga) in Rupiah
   - Choose stock option: unlimited or specific quantity
   - Click "Simpan Item" to save

2. **Create Cashier Accounts**
   - Select "Kelola User" from the admin dashboard
   - Click "Tambah User" button (floating action button)
   - Enter username and password for the new cashier
   - Click "Simpan" to create the account

3. **Add Dry Cleaning Services**
   - Access "Tambah Item Gosok" for ironing/dry cleaning services
   - Configure items similar to laundry items

### Processing Orders (Cashier)

1. **Login as Cashier**
   - Use cashier credentials on the login screen
   - Access the "Kasir Laundry" interface

2. **Create New Order**
   - Click "Pesan Laundry" or "Pesan Gosok"
   - Enter customer name (Nama Pemesan)
   - Select items using the +/- buttons
   - Review total items and price at the bottom
   - Complete the order

3. **View Order History**
   - Access "History Laundry" or "History Gosok"
   - Search orders by name or item
   - View complete order details and payment status

## User Roles

- **Admin**: Full access to all management features, user creation, and item configuration
- **Cashier**: Access to order processing, viewing history, and customer transactions

## Technical Details

- Built with Flutter framework
- Runs on Android devices and emulators
- Indonesian language interface (Bahasa Indonesia)
- Currency: Indonesian Rupiah (Rp)

## Features Summary

✅ Admin account setup and management  
✅ User role management (Admin/Cashier)  
✅ Item management with pricing and stock control  
✅ Order processing with real-time calculations  
✅ Order history with search functionality  
✅ Payment status tracking  
✅ Separate laundry and dry cleaning services  

## Notes

- All items can be deleted using the trash icon button
- Stock tracking available for inventory management
- Real-time order status updates
- Search functionality for quick order lookup
- Secure login system for both admin and cashier roles

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

