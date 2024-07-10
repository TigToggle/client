import 'dart:developer';

import 'package:fluffychat/pangea/constants/age_limits.dart';
import 'package:fluffychat/pangea/controllers/pangea_controller.dart';
import 'package:fluffychat/pangea/extensions/client_extension/client_extension.dart';
import 'package:fluffychat/pangea/pages/p_user_age/p_user_age_view.dart';
import 'package:fluffychat/pangea/utils/p_extension.dart';
import 'package:fluffychat/widgets/fluffy_chat_app.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:intl/intl.dart';

import '../../utils/bot_name.dart';
import '../../utils/error_handler.dart';

class PUserAge extends StatefulWidget {
  const PUserAge({super.key});

  @override
  PUserAgeController createState() => PUserAgeController();
}

class PUserAgeController extends State<PUserAge> {
  bool loading = false;
  int? selectedAge;
  TextEditingController dobController = TextEditingController();

  String? error;
  bool unknownErrorState = false;

  final PangeaController pangeaController = MatrixState.pangeaController;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      if (!(await Matrix.of(context).client.hasBotDM)) {
        Matrix.of(context)
            .client
            .startDirectChat(
              BotName.byEnvironment,
              enableEncryption: false,
            )
            .onError(
              (error, stackTrace) =>
                  ErrorHandler.logError(e: error, s: stackTrace),
            );
      }
    });
  }

  String? dobValidator() {
    try {
      if (selectedDate == null) {
        return L10n.of(context)!.yourBirthdayPleaseShort;
      }
      if (!selectedDate!.isAtLeastYearsOld(AgeLimits.toUseTheApp)) {
        return L10n.of(context)!.mustBe13;
      }
      return null;
    } catch (err, stack) {
      ErrorHandler.logError(e: err, s: stack);
      return L10n.of(context)!.invalidDob;
    }
  }

  DateTime? get selectedDate {
    if (selectedAge == null) return null;
    final now = DateTime.now();
    return DateTime(now.year - selectedAge!, now.month, now.day);
  }

  //Note: used linear progress bar (also used in fluffychat signup button) for consistency
  createUserInPangea() async {
    try {
      setState(() {
        error = dobValidator();
      });

      if (error?.isNotEmpty == true) return;

      setState(() {
        loading = true;
      });

      final String date = DateFormat('yyyy-MM-dd').format(selectedDate!);

      if (pangeaController.userController.userModel?.access == null) {
        await pangeaController.userController.createProfile(dob: date);
      } else {
        await pangeaController.userController.updateUserProfile(
          dateOfBirth: date,
        );
      }
      FluffyChatApp.router.go('/rooms');
    } catch (err, s) {
      setState(() {
        unknownErrorState = true;
      });
      debugger(when: kDebugMode);
      ErrorHandler.logError(e: err, s: s);
    } finally {
      loading = false;
    }
  }

  void setSelectedAge(int? value) {
    setState(() {
      selectedAge = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return !unknownErrorState
        ? PUserAgeView(this)
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Text(
                "${L10n.of(context)!.oopsSomethingWentWrong} \n ${L10n.of(context)!.errorPleaseRefresh}",
              ),
            ),
          );
  }
}
