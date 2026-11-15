# Alarm Bareng (alarm_friendslop)

Aplikasi alarm Flutter yang dikelompokkan dalam **room** yang bisa dishare. Konsepnya mirip game-game "friendslop" (rame-rame bareng teman), tapi isinya alarm biasa: siapa pun yang punya kode/link room bisa menambah, mengubah, dan menghapus alarm di dalamnya.

> **Status: fase 1 (local-first).** Semua data disimpan di SQLite lokal. Kode/link room belum bisa dipakai antar device karena belum ada backend. Lihat [Roadmap](#roadmap).

## Fitur

- Buat, ganti nama, dan hapus **room**
- **CRUD alarm** di dalam room: tambah, edit jam/label, hapus (swipe), toggle on/off
- Alarm **sekali** atau **berulang mingguan** (pilih hari Sen–Min)
- Alarm sekali otomatis mati setelah bunyi
- **Share** room lewat share sheet (nama, kode, dan link)
- Gabung room lewat kode atau link
- Alarm bunyi walau app ditutup (dijadwalkan ke OS), dijadwalkan ulang setelah reboot

## Cara kerja alarm

Bunyi atau tidaknya alarm **murni berdasarkan jam device**. App menjadwalkan notifikasi exact alarm ke OS lewat `flutter_local_notifications` (mode `alarmClock`, full-screen intent, suara berulang sampai di-dismiss). Setiap perubahan alarm (tambah, edit, hapus, toggle) langsung disinkronkan ke jadwal OS lewat `AlarmService`.

## Struktur project

```
lib/
  main.dart                  # entry point, inisialisasi DB + AlarmService
  datamodels/
    models.dart              # Room, AlarmItem
    data.dart                # AlarmRepository (abstract) + SqliteAlarmRepository
  services/
    alarm_service.dart       # penjadwalan alarm ke OS + logika sinkronisasi
  ui/
    ui.dart                  # RoomListScreen, RoomDetailScreen, AlarmEditScreen
```

Arsitektur singkatnya: UI hanya bicara ke `AlarmService`, dan `AlarmService` bicara ke `AlarmRepository`. Karena repository berupa interface, penyimpanan lokal nanti bisa diganti Firebase/Supabase/REST tanpa mengubah UI.

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

Di dalam `<manifest>`, di atas `<application>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

Di dalam `<application>`:

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

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
| `flutter_local_notifications` | Penjadwalan alarm ke OS |
| `timezone`, `flutter_timezone` | Perhitungan waktu sesuai zona device |
| `share_plus` | Share kode/link room |

Versi di-pin ke `flutter_local_notifications ^19`, `share_plus ^10`, dan `flutter_timezone ^4` karena API-nya berubah di versi yang lebih baru.

## Keterbatasan saat ini

- Kode/link room hanya dikenali di device yang sama (belum ada sync).
- Link share (`alarmbareng.example`) masih placeholder, belum ada deep link.
- Alarm berupa notifikasi full-screen, belum ada layar alarm custom.
- Belum ada autentikasi atau pembatasan hak akses: siapa pun yang punya kode berhak penuh (CRUD).

## Roadmap

- [ ] Backend (Firebase/Supabase) dengan implementasi `AlarmRepository` baru
- [ ] Sinkronisasi realtime antar device
- [ ] Deep link supaya link share langsung membuka room
- [ ] Penanganan konflik edit bersamaan
- [ ] Layar alarm custom (mis. memakai package `alarm`)
- [ ] Hak akses per room (owner vs anggota)
