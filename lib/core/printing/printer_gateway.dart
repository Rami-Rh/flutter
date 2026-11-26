import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Imprimante Bluetooth déjà appairée (Android) ou détectée à proximité (iOS).
@immutable
class PrinterDevice {
  const PrinterDevice({required this.name, required this.address});

  final String name;
  final String address;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrinterDevice &&
          other.name == name &&
          other.address == address);

  @override
  int get hashCode => Object.hash(name, address);
}

/// Accès abstrait à l'imprimante thermique Bluetooth.
///
/// L'implémentation réelle s'appuie sur `print_bluetooth_thermal` ; les tests
/// fournissent un double, ce qui évite toute dépendance native.
abstract class PrinterGateway {
  /// Vrai si le Bluetooth est actif sur l'appareil.
  Future<bool> isBluetoothEnabled();

  /// Vrai si l'application a l'autorisation Bluetooth (Android 12+).
  Future<bool> isPermissionGranted();

  /// Imprimantes appairées (Android) ou détectées (iOS).
  Future<List<PrinterDevice>> pairedDevices();

  /// Vrai si une imprimante est déjà connectée.
  Future<bool> isConnected();

  /// Ouvre la connexion à l'imprimante [address].
  Future<bool> connect(String address);

  /// Envoie un flux d'octets (commandes ESC/POS) à l'imprimante.
  Future<bool> writeBytes(List<int> bytes);

  /// Ferme la connexion en cours.
  Future<void> disconnect();
}

/// Implémentation Bluetooth réelle (imprimantes thermiques ESC/POS).
class BluetoothPrinterGateway implements PrinterGateway {
  const BluetoothPrinterGateway();

  @override
  Future<bool> isBluetoothEnabled() => PrintBluetoothThermal.bluetoothEnabled;

  @override
  Future<bool> isPermissionGranted() =>
      PrintBluetoothThermal.isPermissionBluetoothGranted;

  @override
  Future<List<PrinterDevice>> pairedDevices() async {
    final List<BluetoothInfo> devices =
        await PrintBluetoothThermal.pairedBluetooths;
    return devices
        .map(
          (BluetoothInfo device) => PrinterDevice(
            name: device.name,
            address: device.macAdress,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<bool> isConnected() => PrintBluetoothThermal.connectionStatus;

  @override
  Future<bool> connect(String address) =>
      PrintBluetoothThermal.connect(macPrinterAddress: address);

  @override
  Future<bool> writeBytes(List<int> bytes) =>
      PrintBluetoothThermal.writeBytes(bytes);

  @override
  Future<void> disconnect() => PrintBluetoothThermal.disconnect;
}

/// Imprimante thermique de l'application.
final Provider<PrinterGateway> printerGatewayProvider = Provider<PrinterGateway>(
  (Ref ref) => const BluetoothPrinterGateway(),
  name: 'printerGatewayProvider',
);
