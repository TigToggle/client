import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/pages/chat/events/message_content.dart';
import 'package:fluffychat/pangea/enum/use_type.dart';
import 'package:fluffychat/pangea/matrix_event_wrappers/pangea_message_event.dart';
import 'package:fluffychat/pangea/widgets/chat/message_toolbar.dart';
import 'package:fluffychat/utils/date_time_extension.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../../../config/app_config.dart';

class OverlayMessage extends StatelessWidget {
  final Event event;
  final Event? nextEvent;
  final Event? previousEvent;
  final bool selected;
  final Timeline timeline;
  // final LanguageModel? selectedDisplayLang;
  final bool immersionMode;
  // final bool definitions;
  final bool ownMessage;
  final ToolbarDisplayController toolbarController;
  final double? width;

  const OverlayMessage(
    this.event, {
    this.nextEvent,
    this.previousEvent,
    this.selected = false,
    required this.timeline,
    required this.immersionMode,
    required this.ownMessage,
    required this.toolbarController,
    this.width,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (event.type != EventTypes.Message ||
        event.messageType == EventTypes.KeyVerificationRequest) {
      return const SizedBox.shrink();
    }

    var color = Theme.of(context).colorScheme.surfaceContainerHighest;
    final isLight = Theme.of(context).brightness == Brightness.light;
    var lightness = isLight ? .05 : .85;
    final textColor = ownMessage
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    const hardCorner = Radius.circular(4);

    final displayTime = event.type == EventTypes.RoomCreate ||
        nextEvent == null ||
        !event.originServerTs.sameEnvironment(nextEvent!.originServerTs);

    final nextEventSameSender = nextEvent != null &&
        {
          EventTypes.Message,
          EventTypes.Sticker,
          EventTypes.Encrypted,
        }.contains(nextEvent!.type) &&
        nextEvent!.senderId == event.senderId &&
        !displayTime;

    final previousEventSameSender = previousEvent != null &&
        {
          EventTypes.Message,
          EventTypes.Sticker,
          EventTypes.Encrypted,
        }.contains(previousEvent!.type) &&
        previousEvent!.senderId == event.senderId &&
        previousEvent!.originServerTs.sameEnvironment(event.originServerTs);

    const roundedCorner = Radius.circular(AppConfig.borderRadius);
    final borderRadius = BorderRadius.only(
      topLeft: !ownMessage && nextEventSameSender ? hardCorner : roundedCorner,
      topRight: ownMessage && nextEventSameSender ? hardCorner : roundedCorner,
      bottomLeft:
          !ownMessage && previousEventSameSender ? hardCorner : roundedCorner,
      bottomRight:
          ownMessage && previousEventSameSender ? hardCorner : roundedCorner,
    );

    final noBubble = {
          MessageTypes.Video,
          MessageTypes.Image,
          MessageTypes.Sticker,
        }.contains(event.messageType) &&
        !event.redacted;
    final noPadding = {
      MessageTypes.File,
      MessageTypes.Audio,
    }.contains(event.messageType);

    if (ownMessage) {
      color = Theme.of(context).colorScheme.primary;
      lightness = isLight ? .15 : .85;
    }
    // Make overlay a little darker/lighter than the message
    color = Color.fromARGB(
      color.alpha,
      isLight
          ? (color.red + lightness * (255 - color.red)).round()
          : (color.red * lightness).round(),
      isLight
          ? (color.green + lightness * (255 - color.green)).round()
          : (color.green * lightness).round(),
      isLight
          ? (color.blue + lightness * (255 - color.blue)).round()
          : (color.blue * lightness).round(),
    );

    final pangeaMessageEvent = PangeaMessageEvent(
      event: event,
      timeline: timeline,
      ownMessage: ownMessage,
    );

    return Flexible(
      child: SingleChildScrollView(
        child: Material(
          color: noBubble ? Colors.transparent : color,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppConfig.borderRadius,
              ),
            ),
            padding: noBubble || noPadding
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
            constraints: BoxConstraints(
              maxWidth: width ?? FluffyThemes.columnWidth * 1.25,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: MessageContent(
                    event.getDisplayEvent(timeline),
                    textColor: textColor,
                    borderRadius: borderRadius,
                    selected: selected,
                    pangeaMessageEvent: pangeaMessageEvent,
                    immersionMode: immersionMode,
                    toolbarController: toolbarController,
                    isOverlay: true,
                  ),
                ),
                if (event.hasAggregatedEvents(
                      timeline,
                      RelationshipTypes.edit,
                    ) ||
                    (pangeaMessageEvent.showUseType))
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 4.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pangeaMessageEvent.showUseType) ...[
                          pangeaMessageEvent.msgUseType.iconView(
                            context,
                            textColor.withAlpha(164),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (event.hasAggregatedEvents(
                          timeline,
                          RelationshipTypes.edit,
                        )) ...[
                          Icon(
                            Icons.edit_outlined,
                            color: textColor.withAlpha(164),
                            size: 14,
                          ),
                          Text(
                            ' - ${event.getDisplayEvent(timeline).originServerTs.localizedTimeShort(context)}',
                            style: TextStyle(
                              color: textColor.withAlpha(164),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
