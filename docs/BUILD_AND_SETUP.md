# Configuration native et build (Android / iOS)

Ce document couvre la partie native nécessaire aux modules caméra, Bluetooth,
notifications et biométrie. À appliquer après `flutter create .`.

---

## 1. Ordre des commandes

```bash
flutter create . --platforms=android,ios
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter test
flutter run
```

> `flutter create .` génère `android/` et `ios/` sans écraser `lib/`.
> Relancer `build_runner` après chaque modification des tables Drift.

---

## 2. Android

### 2.1 `android/app/build.gradle`

```gradle
android {
    defaultConfig {
        minSdkVersion 23        // mobile_scanner, local_auth, sqlcipher
        targetSdkVersion 34
        multiDexEnabled true
    }
    compileOptions {
        coreLibraryDesugaringEnabled true   // requis par flutter_local_notifications
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

### 2.2 `android/app/src/main/AndroidManifest.xml`

Ajouter **avant** la balise `<application>` :

```xml
<!-- Caméra : scan de codes-barres -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Bluetooth : impression thermique ESC/POS -->
<uses-permission android:name="android.permission.BLUETOOTH"
    android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
    android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />

<!-- Android 12+ : appairage d'imprimantes -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
    android:maxSdkVersion="30" />

<!-- Notifications d'alerte de stock (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Biométrie -->
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

Dans `<application>` (si `image_picker`/`file_picker` sont utilisés, sinon optionnel) :

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize" />
```

> **Aucune permission INTERNET** n'est nécessaire : l'application est
> entièrement hors-ligne. Si tu ajoutes plus tard Firebase Auth (option A du
> cahier des charges), il faudra alors `<uses-permission android:name="android.permission.INTERNET" />`.

### 2.3 `MainActivity` — requis par `local_auth`

La biométrie (`local_auth`) exige que l'activité principale hérite de
`FlutterFragmentActivity` (et non `FlutterActivity`) ; sinon
`isDeviceSupported()` / `authenticate()` échouent silencieusement.

`android/app/src/main/kotlin/<votre_package>/MainActivity.kt` :

```kotlin
package com.example.gestion_stock

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

### 2.4 Signature de release (optionnel)

Créer `android/key.properties` (à ne pas committer, déjà dans `.gitignore`) puis
référencer la `signingConfig` dans `build.gradle`.

---

## 3. iOS

### 3.1 `ios/Podfile`

```ruby
platform :ios, '13.0'
```

### 3.2 `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>L'application utilise la caméra pour scanner les codes-barres des produits.</string>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>L'application utilise le Bluetooth pour imprimer les tickets sur une imprimante thermique.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>L'application utilise le Bluetooth pour imprimer les tickets sur une imprimante thermique.</string>

<key>NSFaceIDUsageDescription</key>
<string>Utiliser Face ID pour déverrouiller l'application.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Choisir le logo du magasin depuis vos photos.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Enregistrer les rapports et étiquettes générés.</string>
```

> Les textes d'usage peuvent être localisés via `ios/Runner/ar.lproj/InfoPlist.strings`
> et `ios/Runner/fr.lproj/InfoPlist.strings`.

### 3.3 Mentions de confidentialité (App Store)

- Chiffrement : ajouter `ITSAppUsesNonExemptEncryption = false` dans
  `Info.plist` si tu n'utilises que le chiffrement fourni par le système
  (SQLCipher sur le contenu utilisateur est typiquement exempté, à vérifier).

---

## 4. Polices pour l'arabe (tickets + rapports PDF)

Les rapports PDF et l'impression thermique de l'arabe nécessitent une police
embarquant le jeu de glyphes arabe (Cairo ou Amiri).

1. Télécharger `Cairo-Regular.ttf`, `Cairo-Bold.ttf` (et/ou `Amiri-Regular.ttf`).
2. Les déposer dans `assets/fonts/`.
3. Décommenter le bloc `fonts:` dans `pubspec.yaml`.
4. Enregistrer la police auprès de `printing` (`PdfGoogleFonts` n'est **pas**
   utilisable hors-ligne : charger la police depuis les assets).

> Sur les imprimantes thermiques qui ne gèrent pas l'arabe nativement, le texte
> est rendu en **image bitmap** (voir Phase 6) avant envoi ESC/POS.

---

## 5. Vérifications après build

- [ ] Scanner un code-barres avec la caméra (permission accordée).
- [ ] Générer un EAN-13 interne (préfixe `200`) et vérifier l'unicité.
- [ ] Imprimer un ticket de test 58 mm puis 80 mm (arabe + français).
- [ ] Déclencher une notification d'alerte de stock.
- [ ] Activer/désactiver la biométrie.
- [ ] Chiffrer la base puis relancer l'application (la clé doit être conservée
      dans `flutter_secure_storage`).
