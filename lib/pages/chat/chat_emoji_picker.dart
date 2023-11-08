import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import 'chat.dart';

class ChatEmojiPicker extends StatelessWidget {
  final ChatController controller;
  const ChatEmojiPicker(this.controller, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AnimatedContainer(
      duration: FluffyThemes.animationDuration,
      curve: FluffyThemes.animationCurve,
      height: controller.showEmojiPicker
          ? MediaQuery.of(context).size.height / 2
          : 0,
      child: controller.showEmojiPicker
          ? EmojiPicker(
              onEmojiSelected: controller.onEmojiSelected,
              onBackspacePressed: controller.emojiPickerBackspace,
              config: Config(
                backspaceColor: theme.colorScheme.primary,
                bgColor: Color.lerp(
                  theme.colorScheme.background,
                  theme.colorScheme.primaryContainer,
                  0.25,
                )!,
                iconColor: theme.colorScheme.primary.withOpacity(0.5),
                iconColorSelected: theme.colorScheme.primary,
                indicatorColor: theme.colorScheme.primary,
                noRecents: Text(
                  L10n.of(context)!.emoteKeyboardNoRecents,
                  style: theme.textTheme.bodyLarge,
                ),
                skinToneDialogBgColor: Color.lerp(
                  theme.colorScheme.background,
                  theme.colorScheme.primaryContainer,
                  0.75,
                )!,
                skinToneIndicatorColor: theme.colorScheme.onBackground,
              ),
            )
          : null,
    );
  }
}
