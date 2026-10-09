import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pack/pack_record.dart';
import 'theme/tokens.dart';

/// Opens the dialer with [number] filled in. The user still presses call.
Future<bool> dial(String number) async {
  try {
    return await launchUrl(Uri(scheme: 'tel', path: number));
  } on Exception {
    return false;
  }
}

/// Opens the phone's SMS app at [sender]'s conversation, where the user can
/// delete the text or block the sender. Only the default SMS app may delete
/// texts, so Hudyat cannot do it itself.
Future<bool> openSmsThread(String sender) async {
  try {
    return await launchUrl(Uri(scheme: 'sms', path: sender));
  } on Exception {
    return false;
  }
}

/// Dials the record's number, or asks which one when it has several.
Future<void> callRecord(BuildContext context, PackRecord record) =>
    callNumbers(context, record.name, record.dialable);

/// Dials one of [numbers], asking which when there are several. [name] heads
/// the list.
Future<void> callNumbers(
  BuildContext context,
  String name,
  List<Phone> numbers,
) async {
  if (numbers.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final Phone? choice = numbers.length == 1
      ? numbers.first
      : await showModalBottomSheet<Phone>(
          context: context,
          backgroundColor: HudyatColors.surface,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(name, style: HudyatText.bodyBold),
                ),
                for (final phone in numbers)
                  ListTile(
                    minTileHeight: 52,
                    leading: const Icon(Icons.call, color: HudyatColors.call),
                    title: Text(
                      phone.display,
                      style: HudyatText.data.copyWith(
                        fontSize: 16,
                        color: HudyatColors.ink,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, phone),
                  ),
              ],
            ),
          ),
        );
  final number = choice?.dial;
  if (number == null) return;
  if (!await dial(number)) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not open the dialer. Dial $number.')),
    );
  }
}

/// Leaves the app running behind the launcher, as the Home button does.
/// Closes it as usual where that is not available.
Future<void> sendAppToBackground() async {
  try {
    await const MethodChannel('hudyat/power')
        .invokeMethod<bool>('toBackground');
  } on Object {
    await SystemNavigator.pop();
  }
}
