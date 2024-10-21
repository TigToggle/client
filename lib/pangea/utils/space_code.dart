import 'dart:math';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import '../controllers/pangea_controller.dart';

class SpaceCodeUtil {
  static const codeLength = 6;

  static bool isValidCode(String? spacecode) {
    return spacecode == null || spacecode.length > 4;
  }

  static String generateSpaceCode() {
    final r = Random();
    const chars = 'AaBbCcDdEeFfGgHhiJjKkLMmNnoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    return List.generate(codeLength, (index) => chars[r.nextInt(chars.length)])
        .join();
  }

  static Future<void> joinWithSpaceCodeDialog(
    BuildContext context,
    PangeaController pangeaController,
  ) async {
    final List<String>? spaceCode = await showTextInputDialog(
      context: context,
      title: L10n.of(context)!.joinWithClassCode,
      okLabel: L10n.of(context)!.ok,
      cancelLabel: L10n.of(context)!.cancel,
      textFields: [
        DialogTextField(hintText: L10n.of(context)!.joinWithClassCodeHint),
      ],
    );
    if (spaceCode == null || spaceCode.single.isEmpty) return;
    await pangeaController.classController.joinClasswithCode(
      context,
      spaceCode.first,
    );
  }

  static messageDialog(
    BuildContext context,
    String title,
    void Function()? action,
  ) =>
      showDialog(
        context: context,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          content: Text(title),
          actions: [
            TextButton(
              onPressed: action,
              child: Text(L10n.of(context)!.ok),
            ),
          ],
        ),
      );
}
