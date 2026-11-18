# Alarm Bareng (alarm_friendslop)

Aplikasi alarm Flutter yang dikelompokkan dalam **room** yang bisa dishare. Konsepnya mirip game-game "friendslop" (rame-rame bareng teman), tapi isinya alarm biasa: siapa pun yang punya kode/link room bisa menambah, mengubah, dan menghapus alarm di dalamnya.

> **Status: fase 1 (local-first).** Semua data disimpan di SQLite lokal. Kode/link room belum bisa dipakai antar device karena belum ada backend. Lihat [Roadmap](#roadmap).

## Fitur

- Buat, ganti nama, dan hapus **room**
- **CRUD alarm** di dalam room: tambah, edit jam/label, hapus (swipe), toggle on/off
- Alarm **sekali** atau **berulang mingguan** (pilih hari Sen–Min)
- Alarm sekali hanya dijadwalkan satu kali dan tidak diulang setelah waktunya lewat
- **Share** room lewat share sheet (nama, kode, dan link)
- Gabung room lewat kode atau link
- Alarm bunyi walau app ditutup (dijadwalkan ke OS)
- Layar alarm full-screen dengan tombol **CHECK-IN**
- Gambar pop-up dan suara custom dari URL HTTPS (di-cache lokal sebelum alarm bunyi)
- Alarm uji yang bunyi 30 detik kemudian

## Cara kerja alarm

Bunyi atau tidaknya alarm **murni berdasarkan jam device**. App menjadwalkan exact alarm ke OS lewat package `alarm`, dengan full-screen intent, getar, dan suara berulang sampai di-check-in atau dihentikan. Setiap perubahan alarm (tambah, edit, hapus, toggle) langsung disinkronkan ke jadwal OS lewat `AlarmService`.

Package `alarm` tidak menyediakan repeat langsung. Karena itu alarm mingguan dijadwalkan sebagai alarm tunggal untuk 28 hari ke depan, lalu dijadwalkan ulang saat app dibuka. Alarm sekali disimpan dengan waktu bunyi (`onceAt`) agar tidak dijadwalkan ulang setelah lewat.

## Struktur project

```
lib/
  main.dart                  # entry point, DB, AlarmService, dan deteksi alarm berbunyi
  data_models/
    models.dart              # Room, AlarmItem, dan format share link
    data.dart                # AlarmRepository + implementasi SQLite lokal
  services/
    alarmservice.dart        # penjadwalan OS, repeat 28 hari, dan sinkronisasi
    mediacache.dart          # download/cache gambar dan suara dari URL HTTPS
  ui/
    ui.dart                  # daftar room, detail room, CRUD alarm, dan share
    alarmeditscreen.dart     # form waktu, label, repeat, gambar, dan suara
    ringscreen.dart          # layar full-screen saat alarm berbunyi
```

Arsitektur singkatnya: UI memakai `AlarmService` untuk operasi alarm, sedangkan data room/alarm diakses melalui `AlarmRepository`. Implementasi saat ini adalah `SqliteAlarmRepository`; karena repository berupa interface, penyimpanan lokal nanti bisa diganti Firebase/Supabase/REST tanpa mengubah UI.

## Setup

Butuh Flutter 3.24+ (Dart 3.4+).

```bash
git clone https://github.com/Nurhax/alarm_friendslop.git
cd alarm_friendslop
flutter pub get
flutter run
```

### Konfigurasi Android (wajib)

**1. `android/app/src/main/AndroidManifest.xml`**

Pastikan permission berikut tersedia di dalam `<manifest>` (konfigurasi saat ini sudah menyediakannya):

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

Tidak perlu menambahkan receiver `flutter_local_notifications`; project ini memakai package `alarm`.

**2. `android/app/build.gradle.kts`** (core library desugaring)

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

> Kalau project memakai `build.gradle` (Groovy) dan bukan `.kts`, tulis `coreLibraryDesugaringEnabled true` dan `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'`.

### Catatan testing

- Android 12+: izin **Alarms & reminders** harus aktif (diminta saat app pertama dibuka).
- Test alarm sebaiknya di device asli. Di HP Xiaomi/Oppo/Vivo/Realme, set app ke "No restrictions" dan izinkan autostart, kalau tidak jadwal alarm sering dibunuh sistem.

## Dependencies utama

| Package | Fungsi |
|---|---|
| `sqflite`, `path` | Database SQLite lokal |
| `alarm` | Penjadwalan exact alarm, audio, getar, dan full-screen intent |
| `share_plus` | Share kode/link room |
| `http`, `crypto`, `path_provider` | Download dan cache media berdasarkan URL |
| `permission_handler` | Meminta izin notifikasi dan exact alarm |

Versi package dan SDK yang dipakai tercantum di [`pubspec.yaml`](pubspec.yaml). Project membutuhkan Flutter dengan Dart SDK `>=3.4.0 <4.0.0`.

## Keterbatasan saat ini

- Kode/link room hanya dikenali di device yang sama (belum ada sync).
- Link share (`alarmbareng.example`) masih placeholder, belum ada deep link.
- Jadwal alarm mingguan hanya dibuat 28 hari ke depan dan diisi ulang saat app dibuka.
- Media custom bergantung pada URL HTTPS yang masih tersedia saat pertama kali disimpan.
- Belum ada autentikasi atau pembatasan hak akses: siapa pun yang punya kode berhak penuh (CRUD).

## Roadmap

- [ ] Backend (Firebase/Supabase) dengan implementasi `AlarmRepository` baru
- [ ] Sinkronisasi realtime antar device
- [ ] Deep link supaya link share langsung membuka room
- [ ] Penanganan konflik edit bersamaan
- [ ] Hak akses per room (owner vs anggota)
