import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pangea/onboarding/onboarding.dart';
import 'package:fluffychat/pangea/onboarding/onboarding_constants.dart';

class OnboardingComplete extends StatelessWidget {
  final OnboardingController controller;
  const OnboardingComplete({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isColumnMode = FluffyThemes.isColumnMode(context);
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHigh
                .withAlpha(170),
            borderRadius: BorderRadius.circular(
              10.0,
            ),
          ),
          margin: const EdgeInsets.all(12.0),
          padding: isColumnMode
              ? const EdgeInsets.all(48.0)
              : const EdgeInsets.fromLTRB(
                  48.0,
                  8.0,
                  48.0,
                  0.0,
                ),
          child: isColumnMode
              ? Text(
                  L10n.of(context).getStartedComplete,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 24.0,
                  children: [
                    Text(
                      L10n.of(context).getStartedComplete,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.0,
                      ),
                    ),
                    CachedNetworkImage(
                      imageUrl:
                          "${AppConfig.assetsBaseURL}/${OnboardingConstants.onboardingImageFileName}",
                      fit: BoxFit.cover,
                    ),
                  ],
                ),
        ),
        Positioned(
          right: 16.0,
          top: 16.0,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: controller.closeCompletedMessage,
          ),
        ),
      ],
    );
  }
}
