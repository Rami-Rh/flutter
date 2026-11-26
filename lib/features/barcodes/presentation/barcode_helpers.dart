import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/settings_providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/printing/printer_gateway.dart';
import '../../../core/printing/ticket_printer.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Adresse de l'imprimante thermique : celle mémorisée, sinon choix parmi les
/// appareils appairés (le choix est mémorisé). `null` si l'utilisateur renonce.
///
/// Lève un [AppFailure] (`printerUnavailable`) si le Bluetooth est coupé ou si
/// aucun appareil n'est disponible.
Future<String?> resolveBarcodePrinter(
  BuildContext context,
  WidgetRef ref,
  TicketPrinter printer,
  AppSettings settings,
) async {
  final String? saved = settings.printerAddress;
  if (saved != null && saved.trim().isNotEmpty) return saved;

  if (!await printer.bluetoothEnabled()) {
    throw const AppFailure(
      FailureCode.printerUnavailable,
      debugMessage: 'Bluetooth désactivé.',
    );
  }
  final List<PrinterDevice> devices = await printer.devices();
  if (!context.mounted) return null;
  if (devices.isEmpty) {
    throw const AppFailure(
      FailureCode.printerUnavailable,
      debugMessage: 'Aucune imprimante appairée.',
    );
  }

  final PrinterDevice chosen;
  if (devices.length == 1) {
    chosen = devices.first;
  } else {
    final PrinterDevice? picked = await showPrinterPickerSheet(context, devices);
    if (picked == null) return null;
    chosen = picked;
  }

  await ref.read(settingsControllerProvider).update(
        (AppSettings current) => current.copyWith(
          printerAddress: chosen.address,
          printerName: chosen.name,
        ),
      );
  return chosen.address;
}

/// Feuille de choix parmi les imprimantes disponibles.
Future<PrinterDevice?> showPrinterPickerSheet(
  BuildContext context,
  List<PrinterDevice> devices,
) {
  return showModalBottomSheet<PrinterDevice>(
    context: context,
    useSafeArea: true,
    builder: (BuildContext context) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.saleTicketSelectPrinter,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final PrinterDevice device in devices)
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(device.name),
                subtitle: Text(device.address),
                onTap: () => Navigator.of(context).pop(device),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
