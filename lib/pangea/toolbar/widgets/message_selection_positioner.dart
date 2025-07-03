import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/pangea/common/utils/error_handler.dart';
import 'package:fluffychat/pangea/events/event_wrappers/pangea_message_event.dart';
import 'package:fluffychat/pangea/events/models/pangea_token_model.dart';
import 'package:fluffychat/pangea/toolbar/enums/message_mode_enum.dart';
import 'package:fluffychat/pangea/toolbar/enums/reading_assistance_mode_enum.dart';
import 'package:fluffychat/pangea/toolbar/widgets/message_selection_overlay.dart';
import 'package:fluffychat/pangea/toolbar/widgets/overlay_center_content.dart';
import 'package:fluffychat/pangea/toolbar/widgets/reading_assistance_content.dart';
import 'package:fluffychat/pangea/toolbar/widgets/select_mode_buttons.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/matrix.dart';

/// Controls positioning of the message overlay.
class MessageSelectionPositioner extends StatefulWidget {
  final MessageOverlayController overlayController;
  final ChatController chatController;
  final Event event;

  final PangeaMessageEvent? pangeaMessageEvent;
  final PangeaToken? initialSelectedToken;
  final Event? nextEvent;
  final Event? prevEvent;

  const MessageSelectionPositioner({
    required this.overlayController,
    required this.chatController,
    required this.event,
    this.pangeaMessageEvent,
    this.initialSelectedToken,
    this.nextEvent,
    this.prevEvent,
    super.key,
  });

  @override
  MessageSelectionPositionerState createState() =>
      MessageSelectionPositionerState();
}

class MessageSelectionPositionerState extends State<MessageSelectionPositioner>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  Offset? _centeredMessageOffset;
  Size? _centeredMessageSize;

  Size? _tooltipSize;

  final Completer _centeredMessageCompleter = Completer();
  final Completer _tooltipCompleter = Completer();

  MessageMode _currentMode = MessageMode.noneSelected;

  Animation<Offset>? _overlayOffsetAnimation;
  Animation<Size>? _messageSizeAnimation;
  Offset? _currentOffset;

  StreamSubscription? _reactionSubscription;
  StreamSubscription? _contentChangedSubscription;

  ScrollController? _scrollController;

  final _animationDuration = const Duration(
    milliseconds: AppConfig.overlayAnimationDuration,
    // seconds: 5,
  );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    Future.delayed(
      const Duration(milliseconds: 100),
      () {
        if (_scrollController == null || !_scrollController!.hasClients) {
          return;
        }

        _scrollController!.animateTo(
          _scrollController!.position.maxScrollExtent,
          duration: FluffyThemes.animationDuration,
          curve: FluffyThemes.animationCurve,
        );
      },
    );

    _currentMode = widget.overlayController.toolbarMode;
    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    _reactionSubscription =
        widget.chatController.room.client.onSync.stream.where(
      (update) {
        // check if this sync update has a reaction event or a
        // redaction (of a reaction event). If so, rebuild the overlay
        final room = widget.chatController.room;
        final timelineEvents = update.rooms?.join?[room.id]?.timeline?.events;
        if (timelineEvents == null) return false;

        final eventID = widget.event.eventId;
        return timelineEvents.any(
          (e) =>
              e.type == EventTypes.Redaction ||
              (e.type == EventTypes.Reaction &&
                  Event.fromMatrixEvent(e, room).relationshipEventId ==
                      eventID),
        );
      },
    ).listen((_) => setState(() {}));

    _contentChangedSubscription = widget
        .overlayController.contentChangedStream.stream
        .listen(_onContentSizeChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _centeredMessageCompleter.future;
      if (!mounted) return;

      setState(() {
        _currentOffset = Offset(
          _ownMessage ? _messageRightOffset : _messageLeftOffset,
          _originalMessageBottomOffset -
              _reactionsHeight -
              _selectionButtonsHeight,
        );
      });

      _setReadingAssistanceMode(
        ReadingAssistanceMode.selectMode,
      );
    });
  }

  @override
  void didUpdateWidget(MessageSelectionPositioner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mode = widget.overlayController.toolbarMode;
    if (mode != _currentMode) {
      setState(() => _currentMode = mode);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reactionSubscription?.cancel();
    _contentChangedSubscription?.cancel();
    _scrollController?.dispose();
    MatrixState.pangeaController.matrixState.audioPlayer
      ?..stop()
      ..dispose();
    super.dispose();
  }

  void _setCenteredMessageSize(RenderBox renderBox) {
    if (_centeredMessageCompleter.isCompleted) return;

    _centeredMessageSize = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    _centeredMessageOffset = Offset(
      offset.dx - _columnWidth - _horizontalPadding - 2.0,
      _mediaQuery!.size.height -
          (offset.dy -
              ((AppConfig.practiceModeInputBarHeight -
                      AppConfig.selectModeInputBarHeight) *
                  0.75)) -
          renderBox.size.height -
          _reactionsHeight,
    );
    setState(() {});

    if (!_centeredMessageCompleter.isCompleted) {
      _centeredMessageCompleter.complete();
    }
  }

  void _setTooltipSize(RenderBox renderBox) {
    setState(() {
      _tooltipSize = renderBox.size;
    });

    if (!_tooltipCompleter.isCompleted) {
      _tooltipCompleter.complete();
    }
  }

  Future<void> _setReadingAssistanceMode(ReadingAssistanceMode mode) async {
    if (mode == _readingAssistanceMode) {
      return;
    }

    await _centeredMessageCompleter.future;

    if (mode == ReadingAssistanceMode.practiceMode) {
      setState(
        () => widget.overlayController.readingAssistanceMode =
            ReadingAssistanceMode.transitionMode,
      );
    } else if (mode == ReadingAssistanceMode.selectMode) {
      setState(
        () => widget.overlayController.readingAssistanceMode =
            ReadingAssistanceMode.selectMode,
      );
    }

    if (mode == ReadingAssistanceMode.selectMode) {
      _resetOffsetAnimation(_adjustedOriginalMessageOffset);
    } else if (mode == ReadingAssistanceMode.practiceMode) {
      _resetOffsetAnimation(_centeredMessageOffset!);
      _messageSizeAnimation = Tween<Size>(
        begin: Size(
          _originalMessageSize.width,
          _originalMessageSize.height,
        ),
        end: _adjustedCenteredMessageSize,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: FluffyThemes.animationCurve,
        ),
      );
    }

    await _animationController.forward(from: 0);
    if (mounted) {
      setState(() => widget.overlayController.readingAssistanceMode = mode);
    }
  }

  void _onContentSizeChanged(_) {
    Future.delayed(FluffyThemes.animationDuration, () {
      final offset = _overlayMessageRenderBox?.localToGlobal(Offset.zero);
      if (offset == null || !_overlayMessageRenderBox!.hasSize) {
        return null;
      }

      final newOffset = _adjustedMessageOffset(
        _overlayMessageRenderBox!.size,
        offset,
      );

      if (newOffset == _currentOffset) return;
      _resetOffsetAnimation(newOffset);
      _animationController.forward(from: 0);
    });
  }

  void _resetOffsetAnimation(Offset offset) {
    _overlayOffsetAnimation = Tween<Offset>(
      begin: _currentOffset,
      end: offset,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: FluffyThemes.animationCurve,
      ),
    )..addListener(() {
        if (mounted) {
          setState(() => _currentOffset = _overlayOffsetAnimation?.value);
        }
      });
  }

  T _runWithLogging<T>(
    Function runner,
    String errorMessage,
    T defaultValue,
  ) {
    try {
      return runner();
    } catch (e, s) {
      ErrorHandler.logError(
        e: "$errorMessage: $e",
        s: s,
        data: {
          "eventID": widget.event.eventId,
        },
      );
      return defaultValue;
    }
  }

  ReadingAssistanceMode? get _readingAssistanceMode =>
      widget.overlayController.readingAssistanceMode;

  double get _inputBarSize =>
      _readingAssistanceMode == ReadingAssistanceMode.practiceMode ||
              _readingAssistanceMode == ReadingAssistanceMode.transitionMode
          ? AppConfig.practiceModeInputBarHeight
          : AppConfig.selectModeInputBarHeight;

  bool get _showDetails =>
      AppSettings.displayChatDetailsColumn.getItem(Matrix.of(context).store) &&
      FluffyThemes.isThreeColumnMode(context) &&
      widget.chatController.room.membership == Membership.join;

  // screen size

  MediaQueryData? get _mediaQuery => _runWithLogging<MediaQueryData?>(
        () => MediaQuery.of(context),
        "Error getting media query",
        null,
      );

  double get _columnWidth => FluffyThemes.isColumnMode(context)
      ? (FluffyThemes.columnWidth + FluffyThemes.navRailWidth + 1.0)
      : 0;

  /// Available vertical space not taken up by the header and footer
  double? get _verticalSpace {
    if (_mediaQuery == null) return null;
    return _mediaQuery!.size.height - _headerHeight - _footerHeight;
  }

  double get _toolbarMaxWidth {
    const double messageMargin = 16.0;
    // widget.event.isActivityMessage ? 0 : Avatar.defaultSize + 16 + 8;
    final bool showingDetails = widget.chatController.displayChatDetailsColumn;
    final double totalMaxWidth = (FluffyThemes.columnWidth * 2.5) -
        (showingDetails ? FluffyThemes.columnWidth : 0) -
        messageMargin;
    double? maxWidth;

    if (_mediaQuery != null) {
      final chatViewWidth = _mediaQuery!.size.width - _columnWidth;
      maxWidth = chatViewWidth - (2 * _horizontalPadding) - messageMargin;
    }

    if (maxWidth == null || maxWidth > totalMaxWidth) {
      maxWidth = totalMaxWidth;
    }

    return maxWidth;
  }

  // original message size and offset

  RenderBox? get _messageRenderBox => _runWithLogging<RenderBox?>(
        () => MatrixState.pAnyState.getRenderBox(
          widget.event.eventId,
        ),
        "Error getting message render box",
        null,
      );

  RenderBox? get _overlayMessageRenderBox => _runWithLogging<RenderBox?>(
        () => MatrixState.pAnyState.getRenderBox(
          'overlay_message_${widget.event.eventId}',
        ),
        "Error getting overlay message render box",
        null,
      );

  // Offset? get _overlayMessageOffset =>
  //     _overlayMessageRenderBox?.localToGlobal(Offset.zero);

  Size? get _overlayMessageSize => _overlayMessageRenderBox?.size;

  // double? get _buttonsTopOffset {
  //   if (_overlayMessageOffset == null ||
  //       _overlayMessageSize == null ||
  //       _mediaQuery == null) {
  //     return null;
  //   }

  //   const buttonsHeight = 300.0;
  //   final availableSpace = _mediaQuery!.size.height -
  //       _overlayMessageOffset!.dy -
  //       _overlayMessageSize!.height -
  //       _reactionsHeight -
  //       4.0;

  //   if (availableSpace >= buttonsHeight) {
  //     return _overlayMessageOffset!.dy + _overlayMessageSize!.height + 4.0;
  //   }

  //   return _mediaQuery!.size.height - buttonsHeight - 4.0;
  // }

  double get _neededTopSpace =>
      (widget.pangeaMessageEvent != null &&
              widget.overlayController.selectedToken != null
          ? AppConfig.toolbarMaxHeight
          : 40.0) +
      4.0;

  double? get _occupiedSpace {
    if (_overlayMessageSize == null) return null;
    return _overlayMessageSize!.height +
        _reactionsHeight +
        AppConfig.toolbarMenuHeight;
  }

  double? get _wordCardTopOffset {
    if (_overlayMessageSize == null ||
        _mediaQuery == null ||
        _occupiedSpace == null) {
      return null;
    }

    final availableSpace = (_mediaQuery!.size.height - _occupiedSpace!) / 2;

    if (availableSpace >= _neededTopSpace) {
      return availableSpace - _neededTopSpace;
    }

    return 0;
  }

  Size get _defaultMessageSize => const Size(FluffyThemes.columnWidth / 2, 100);

  /// The size of the message in the chat list (as opposed to the expanded size in the center overlay)
  Size get _originalMessageSize {
    if (_messageRenderBox == null || !_messageRenderBox!.hasSize) {
      return _defaultMessageSize;
    }

    return _runWithLogging(
      () => _messageRenderBox?.size,
      "Error getting message size",
      _defaultMessageSize,
    );
  }

  static const _messageDefaultLeftMargin = Avatar.defaultSize + 16 + 8;

  // Centered message size and offset

  bool get _centeredMessageHasOverflow {
    if (_verticalSpace == null ||
        _centeredMessageSize == null ||
        _centeredMessageOffset == null) {
      return false;
    }

    final finalMessageHeight = _centeredMessageSize!.height + _reactionsHeight;
    return finalMessageHeight > _verticalSpace!;
  }

  /// Size of the centered overlay message adjusted for overflow
  Size? get _adjustedCenteredMessageSize {
    if (_centeredMessageHasOverflow) {
      return Size(
        _centeredMessageSize!.width,
        _verticalSpace! - (AppConfig.toolbarSpacing * 2),
      );
    }
    return _centeredMessageSize;
  }

  Offset? get _adjustedCenteredMessageOffset {
    if (_centeredMessageHasOverflow) {
      return Offset(
        _centeredMessageOffset!.dx,
        _footerHeight + AppConfig.toolbarSpacing,
      );
    }
    return _centeredMessageOffset;
  }

  // message offset

  static const Offset _defaultMessageOffset =
      Offset(_messageDefaultLeftMargin, 300);

  Offset get _originalMessageOffset {
    if (_messageRenderBox == null || !_messageRenderBox!.hasSize) {
      return _defaultMessageOffset;
    }
    return _runWithLogging(
      () => _messageRenderBox?.localToGlobal(Offset.zero),
      "Error getting message offset",
      _defaultMessageOffset,
    );
  }

  Offset get _adjustedOriginalMessageOffset {
    return _adjustedMessageOffset(
      _originalMessageSize,
      _originalMessageOffset,
    );
  }

  Offset _adjustedMessageOffset(
    Size messageSize,
    Offset messageOffset,
  ) {
    if (_messageRenderBox == null || !_messageRenderBox!.hasSize) {
      return _defaultMessageOffset;
    }

    final topOffset = messageOffset.dy;
    final bottomOffset =
        (_mediaQuery!.size.height - topOffset - messageSize.height) -
            _reactionsHeight -
            _selectionButtonsHeight;

    final hasHeaderOverflow =
        topOffset < (_headerHeight + AppConfig.toolbarSpacing);
    final hasFooterOverflow =
        bottomOffset < (_footerHeight + AppConfig.toolbarSpacing);

    if (!hasHeaderOverflow && !hasFooterOverflow) {
      return Offset(
        _ownMessage ? _messageRightOffset : _messageLeftOffset,
        bottomOffset,
      );
    }

    if (hasHeaderOverflow) {
      final difference = topOffset - (_headerHeight + AppConfig.toolbarSpacing);

      double newBottomOffset = _mediaQuery!.size.height -
          topOffset +
          difference -
          messageSize.height -
          _selectionButtonsHeight;

      if (newBottomOffset < _footerHeight + AppConfig.toolbarSpacing) {
        newBottomOffset = _footerHeight + AppConfig.toolbarSpacing;
      }

      return Offset(
        _ownMessage ? _messageRightOffset : _messageLeftOffset,
        newBottomOffset,
      );
    } else {
      return Offset(
        _ownMessage ? _messageRightOffset : _messageLeftOffset,
        _footerHeight + (AppConfig.toolbarSpacing * 2),
      );
    }
  }

  double get _originalMessageBottomOffset =>
      _mediaQuery!.size.height -
      _originalMessageOffset.dy -
      _originalMessageSize.height;

  double? get _centeredMessageTopOffset {
    if (_mediaQuery == null ||
        _adjustedCenteredMessageOffset == null ||
        _adjustedCenteredMessageSize == null) {
      return null;
    }
    return _mediaQuery!.size.height -
        _adjustedCenteredMessageOffset!.dy -
        _adjustedCenteredMessageSize!.height -
        _reactionsHeight;
  }

  double get _messageLeftOffset {
    if (_ownMessage) return 0;
    return max(
      _originalMessageOffset.dx - _columnWidth - _horizontalPadding,
      0,
    );
  }

  double get _messageRightOffset {
    if (_mediaQuery == null || !_ownMessage) {
      return 0;
    }
    return _mediaQuery!.size.width -
        _originalMessageOffset.dx -
        _originalMessageSize.width -
        _horizontalPadding -
        (_showDetails ? FluffyThemes.columnWidth : 0);
  }

  // measurements for items around the toolbar

  double get _horizontalPadding =>
      FluffyThemes.isColumnMode(context) ? 8.0 : 0.0;

  double get _headerHeight {
    return (Theme.of(context).appBarTheme.toolbarHeight ??
            AppConfig.defaultHeaderHeight) +
        (_mediaQuery?.padding.top ?? 0);
  }

  double get _footerHeight {
    return _inputBarSize + (_mediaQuery?.padding.bottom ?? 0);
  }

  // measurement for items in the toolbar

  bool get _showButtons {
    if (!(widget.pangeaMessageEvent?.shouldShowToolbar ?? false)) {
      return false;
    }

    final type = widget.pangeaMessageEvent?.event.messageType;
    if (![MessageTypes.Text, MessageTypes.Audio].contains(type)) {
      return false;
    }

    if (type == MessageTypes.Text) {
      return widget.pangeaMessageEvent?.messageDisplayLangIsL2 ?? false;
    }

    return true;
  }

  bool get showPracticeButtons =>
      _showButtons &&
      widget.overlayController.readingAssistanceMode ==
          ReadingAssistanceMode.practiceMode;

  bool get showSelectionButtons =>
      _showButtons &&
      [ReadingAssistanceMode.selectMode, null]
          .contains(widget.overlayController.readingAssistanceMode);

  double get _selectionButtonsHeight {
    return showSelectionButtons ? AppConfig.toolbarButtonsHeight : 0;
  }

  bool get _hasReactions {
    final reactionsEvents = widget.event.aggregatedEvents(
      widget.chatController.timeline!,
      RelationshipTypes.reaction,
    );
    return reactionsEvents.where((e) => !e.redacted).isNotEmpty;
  }

  double get _reactionsHeight => _hasReactions ? 28 : 0;

  bool get _ownMessage =>
      widget.event.senderId == widget.event.room.client.userID;

  double get _readingAssistanceModeOpacity {
    switch (_readingAssistanceMode) {
      case ReadingAssistanceMode.practiceMode:
      case ReadingAssistanceMode.transitionMode:
        return 0.8;
      case ReadingAssistanceMode.selectMode:
      case null:
        return 0.6;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_messageRenderBox == null || _mediaQuery == null) {
      return const SizedBox.shrink();
    }

    widget.overlayController.maxWidth = _toolbarMaxWidth;

    debugPrint(
      "width: ${_mediaQuery!.size.width - _columnWidth - (_showDetails ? FluffyThemes.columnWidth : 0)}",
    );

    return Row(
      children: [
        Column(
          children: [
            Expanded(
              child: SizedBox(
                width: _mediaQuery!.size.width -
                    _columnWidth -
                    (_showDetails ? FluffyThemes.columnWidth : 0),
                child: Stack(
                  alignment: _ownMessage
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  children: [
                    GestureDetector(
                      onTap: widget.chatController.clearSelectedEvents,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          left: _messageLeftOffset + _horizontalPadding,
                          right: _messageRightOffset + _horizontalPadding,
                        ),
                        child: Column(
                          spacing: 4.0,
                          crossAxisAlignment: _ownMessage
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CompositedTransformTarget(
                              link: MatrixState.pAnyState
                                  .layerLinkAndKey(
                                    'overlay_message_${widget.event.eventId}',
                                  )
                                  .link,
                              child: OverlayCenterContent(
                                event: widget.event,
                                messageHeight: _originalMessageSize.height,
                                messageWidth:
                                    widget.overlayController.showingExtraContent
                                        ? max(_originalMessageSize.width, 150)
                                        : _originalMessageSize.width,
                                overlayController: widget.overlayController,
                                chatController: widget.chatController,
                                nextEvent: widget.nextEvent,
                                prevEvent: widget.prevEvent,
                                hasReactions: _hasReactions,
                                sizeAnimation: _messageSizeAnimation,
                                isTransitionAnimation: true,
                                readingAssistanceMode: _readingAssistanceMode,
                              ),
                            ),
                            SelectModeButtons(
                              controller: widget.chatController,
                              overlayController: widget.overlayController,
                              lauchPractice: () {
                                _setReadingAssistanceMode(
                                  ReadingAssistanceMode.practiceMode,
                                );
                                widget.overlayController
                                    .updateSelectedSpan(null);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_wordCardTopOffset != null)
                      AnimatedPositioned(
                        top: _wordCardTopOffset,
                        left: _ownMessage
                            ? null
                            : _messageLeftOffset + _horizontalPadding,
                        right: _ownMessage
                            ? _messageRightOffset + _horizontalPadding
                            : null,
                        duration: FluffyThemes.animationDuration,
                        child: AnimatedSize(
                          duration: FluffyThemes.animationDuration,
                          child: widget.pangeaMessageEvent != null &&
                                  widget.overlayController.selectedToken != null
                              ? ReadingAssistanceContent(
                                  pangeaMessageEvent:
                                      widget.pangeaMessageEvent!,
                                  overlayController: widget.overlayController,
                                )
                              : MessageReactionPicker(
                                  chatController: widget.chatController,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_showDetails)
          const SizedBox(
            width: FluffyThemes.columnWidth,
          ),
      ],
    );

    // return Align(
    //   alignment: Alignment.centerLeft,
    //   child: SizedBox(
    // width: _mediaQuery!.size.width -
    //     _columnWidth -
    //     (_showDetails ? FluffyThemes.columnWidth : 0),
    //     height: _mediaQuery!.size.height,
    //     child: SingleChildScrollView(
    //       child: Container(
    //         decoration: BoxDecoration(
    //           border: Border.all(color: Colors.green),
    //         ),
    // padding: EdgeInsets.only(
    //   left: _messageLeftOffset + _horizontalPadding,
    //   right: _messageRightOffset + _horizontalPadding,
    // ),
    //         child: Stack(
    //           alignment:
    //               _ownMessage ? Alignment.centerRight : Alignment.centerLeft,
    //           children: [
    //             Positioned.fill(
    //               child: InkWell(
    //                 onTap: widget.chatController.clearSelectedEvents,
    //               ),
    //             ),
    //             Column(
    // spacing: 4.0,
    // crossAxisAlignment: _ownMessage
    //     ? CrossAxisAlignment.end
    //     : CrossAxisAlignment.start,
    //               children: [
    // if (widget.pangeaMessageEvent != null)
    //   AnimatedSize(
    //     duration: FluffyThemes.animationDuration,
    //     child: widget.overlayController.selectedToken != null
    //         ? ReadingAssistanceContent(
    //             pangeaMessageEvent: widget.pangeaMessageEvent!,
    //             overlayController: widget.overlayController,
    //           )
    //         : const SizedBox.shrink(),
    //   ),
    // CompositedTransformTarget(
    //   link: MatrixState.pAnyState
    //       .layerLinkAndKey(
    //         'overlay_message_${widget.event.eventId}',
    //       )
    //       .link,
    //   child: OverlayCenterContent(
    //     event: widget.event,
    //     messageHeight: _originalMessageSize.height,
    //     messageWidth:
    //         widget.overlayController.showingExtraContent
    //             ? max(_originalMessageSize.width, 150)
    //             : _originalMessageSize.width,
    //     overlayController: widget.overlayController,
    //     chatController: widget.chatController,
    //     nextEvent: widget.nextEvent,
    //     prevEvent: widget.prevEvent,
    //     hasReactions: _hasReactions,
    //     sizeAnimation: _messageSizeAnimation,
    //     isTransitionAnimation: true,
    //     readingAssistanceMode: _readingAssistanceMode,
    //   ),
    // ),
    //               ],
    //             ),
    //             if (showSelectionButtons)
    //               Positioned(
    // child: SelectModeButtons(
    //   overlayController: widget.overlayController,
    //   lauchPractice: () {
    //     _setReadingAssistanceMode(
    //       ReadingAssistanceMode.practiceMode,
    //     );
    //     widget.overlayController.updateSelectedSpan(null);
    //   },
    // ),
    //               ),
    //           ],
    //         ),
    //       ),
    //     ),
    //   ),
    // );

    // return Stack(
    //   children: [
    //     Positioned.fill(
    //       child: IgnorePointer(
    //         child: AnimatedOpacity(
    //           duration: _animationDuration,
    //           opacity: _readingAssistanceModeOpacity,
    //           child: Container(
    //             height: double.infinity,
    //             width: double.infinity,
    //             color: Colors.black,
    //           ),
    //         ),
    //       ),
    //     ),
    //     Padding(
    //       padding: EdgeInsets.only(
    //         left: _horizontalPadding,
    //         right: _horizontalPadding,
    //       ),
    //       child: Row(
    //         children: [
    //           Expanded(
    //             child: Stack(
    //               alignment: Alignment.center,
    //               children: [
    //                 Column(
    //                   children: [
    //                     Material(
    //                       type: MaterialType.transparency,
    //                       child: Column(
    //                         children: [
    //                           SizedBox(height: _mediaQuery?.padding.top ?? 0),
    //                           OverlayHeader(controller: widget.chatController),
    //                         ],
    //                       ),
    //                     ),
    //                     const Expanded(
    //                       flex: 3,
    //                       child: SizedBox.shrink(),
    //                     ),
    //                     Opacity(
    //                       opacity: _readingAssistanceMode ==
    //                               ReadingAssistanceMode.practiceMode
    //                           ? 1.0
    //                           : 0.0,
    //   child: OverlayCenterContent(
    //     event: widget.event,
    //     messageHeight: null,
    //     messageWidth: null,
    //     maxWidth: widget.overlayController.maxWidth,
    //     overlayController: widget.overlayController,
    //     chatController: widget.chatController,
    //     pangeaMessageEvent: widget.pangeaMessageEvent,
    //     nextEvent: widget.nextEvent,
    //     prevEvent: widget.prevEvent,
    //     hasReactions: _hasReactions,
    //     onChangeMessageSize: _setCenteredMessageSize,
    //     isTransitionAnimation: false,
    //     maxHeight: _mediaQuery!.size.height -
    //         _headerHeight -
    //         _footerHeight -
    //         AppConfig.toolbarSpacing * 2 -
    //         _selectionButtonsHeight,
    //     readingAssistanceMode: _readingAssistanceMode,
    //   ),
    // ),
    //                     const Expanded(
    //                       flex: 1,
    //                       child: SizedBox.shrink(),
    //                     ),
    //                     Row(
    //                       mainAxisSize: MainAxisSize.min,
    //                       children: [
    //                         Expanded(
    //                           child: Column(
    //                             mainAxisSize: MainAxisSize.min,
    //                             children: [
    //                               OverlayFooter(
    //                                 controller: widget.chatController,
    //                                 overlayController: widget.overlayController,
    //                                 showToolbarButtons: showPracticeButtons,
    //                                 readingAssistanceMode:
    //                                     _readingAssistanceMode,
    //                               ),
    //                               SizedBox(
    //                                 height: _mediaQuery?.padding.bottom ?? 0,
    //                               ),
    //                             ],
    //                           ),
    //                         ),
    //                       ],
    //                     ),
    //                   ],
    //                 ),
    //                 if (_readingAssistanceMode !=
    //                         ReadingAssistanceMode.practiceMode &&
    //                     _readingAssistanceMode != null)
    //                   AnimatedBuilder(
    //                     animation:
    //                         _overlayOffsetAnimation ?? _animationController,
    //                     builder: (context, child) {
    //                       return Positioned(
    //                         left: _ownMessage
    //                             ? null
    //                             : (_overlayOffsetAnimation?.value)?.dx ??
    //                                 _messageLeftOffset,
    //                         right: _ownMessage
    //                             ? (_overlayOffsetAnimation?.value)?.dx ??
    //                                 _messageRightOffset
    //                             : null,
    //                         bottom: (_overlayOffsetAnimation?.value)?.dy ??
    //                             _originalMessageBottomOffset -
    //                                 _reactionsHeight -
    //                                 _selectionButtonsHeight,
    //                         child: Column(
    //                           crossAxisAlignment: _ownMessage
    //                               ? CrossAxisAlignment.end
    //                               : CrossAxisAlignment.start,
    //                           children: [
    // OverlayCenterContent(
    //   event: widget.event,
    //   messageHeight: _originalMessageSize.height,
    //   messageWidth: widget
    //           .overlayController.showingExtraContent
    //       ? max(_originalMessageSize.width, 150)
    //       : _originalMessageSize.width,
    //   maxWidth: widget.overlayController.maxWidth,
    //   overlayController: widget.overlayController,
    //   chatController: widget.chatController,
    //   pangeaMessageEvent: widget.pangeaMessageEvent,
    //   nextEvent: widget.nextEvent,
    //   prevEvent: widget.prevEvent,
    //   hasReactions: _hasReactions,
    //   sizeAnimation: _messageSizeAnimation,
    //   isTransitionAnimation: true,
    //   maxHeight: _mediaQuery!.size.height -
    //       _headerHeight -
    //       _footerHeight -
    //       AppConfig.toolbarSpacing * 2 -
    //       _selectionButtonsHeight,
    //   readingAssistanceMode: _readingAssistanceMode,
    // ),
    // if (showSelectionButtons)
    //   SelectModeButtons(
    //     overlayController: widget.overlayController,
    //     lauchPractice: () {
    //       _setReadingAssistanceMode(
    //         ReadingAssistanceMode.practiceMode,
    //       );
    //       widget.overlayController
    //           .updateSelectedSpan(null);
    //     },
    //   ),
    //                           ],
    //                         ),
    //                       );
    //                     },
    //                   ),
    //                 if (showPracticeButtons)
    //                   Positioned(
    //                     top: 0,
    //                     child: IgnorePointer(
    //                       child: MeasureRenderBox(
    //                         onChange: _setTooltipSize,
    //                         child: Opacity(
    //                           opacity: 0.0,
    //                           child: Container(
    //                             constraints: BoxConstraints(
    //                               minWidth: 200.0,
    //                               maxWidth: _toolbarMaxWidth,
    //                             ),
    //                             child: InstructionsInlineTooltip(
    //                               instructionsEnum: widget.overlayController
    //                                       .toolbarMode.instructionsEnum ??
    //                                   InstructionsEnum
    //                                       .readingAssistanceOverview,
    //                               bold: true,
    //                             ),
    //                           ),
    //                         ),
    //                       ),
    //                     ),
    //                   ),
    //                 if (_centeredMessageTopOffset != null &&
    //                     _tooltipSize != null &&
    //                     widget.overlayController.toolbarMode !=
    //                         MessageMode.noneSelected &&
    //                     widget.overlayController.selectedToken == null)
    //                   Positioned(
    //                     top: max(
    //                       ((_headerHeight + _centeredMessageTopOffset!) / 2) -
    //                           (_tooltipSize!.height / 2),
    //                       _headerHeight,
    //                     ),
    //                     child: Container(
    //                       constraints: BoxConstraints(
    //                         minWidth: 200.0,
    //                         maxWidth: widget.overlayController.maxWidth,
    //                       ),
    //                       child: InstructionsInlineTooltip(
    //                         instructionsEnum: widget.overlayController
    //                                 .toolbarMode.instructionsEnum ??
    //                             InstructionsEnum.readingAssistanceOverview,
    //                         bold: true,
    //                       ),
    //                     ),
    //                   ),
    //               ],
    //             ),
    //           ),
    //           if (_showDetails)
    //             const SizedBox(
    //               width: FluffyThemes.columnWidth,
    //             ),
    //         ],
    //       ),
    //     ),
    //   ],
    // );
  }
}

class MessageReactionPicker extends StatelessWidget {
  final ChatController chatController;
  const MessageReactionPicker({
    super.key,
    required this.chatController,
  });

  @override
  Widget build(BuildContext context) {
    if (chatController.selectedEvents.length != 1) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final sentReactions = <String>{};
    final event = chatController.selectedEvents.first;
    sentReactions.addAll(
      event
          .aggregatedEvents(
            chatController.timeline!,
            RelationshipTypes.reaction,
          )
          .where(
            (event) =>
                event.senderId == event.room.client.userID &&
                event.type == 'm.reaction',
          )
          .map(
            (event) => event.content
                .tryGetMap<String, Object?>('m.relates_to')
                ?.tryGet<String>('key'),
          )
          .whereType<String>(),
    );

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(
        AppConfig.borderRadius,
      ),
      shadowColor: theme.colorScheme.surface.withAlpha(128),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...AppConfig.defaultReactions.map(
              (emoji) => IconButton(
                padding: EdgeInsets.zero,
                icon: Center(
                  child: Opacity(
                    opacity: sentReactions.contains(
                      emoji,
                    )
                        ? 0.33
                        : 1,
                    child: Text(
                      emoji,
                      style: const TextStyle(
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                onPressed: sentReactions.contains(emoji)
                    ? null
                    : () => event.room.sendReaction(
                          event.eventId,
                          emoji,
                        ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.add_reaction_outlined,
              ),
              tooltip: L10n.of(context).customReaction,
              onPressed: () async {
                // final emoji = await showAdaptiveBottomSheet<String>(
                //   context: context,
                //   builder: (context) => Scaffold(
                //     appBar: AppBar(
                //       title: Text(
                //         L10n.of(context).customReaction,
                //       ),
                //       leading: CloseButton(
                //         onPressed: () => Navigator.of(
                //           context,
                //         ).pop(
                //           null,
                //         ),
                //       ),
                //     ),
                //     body: SizedBox(
                //       height: double.infinity,
                //       child: EmojiPicker(
                //         onEmojiSelected: (
                //           _,
                //           emoji,
                //         ) =>
                //             Navigator.of(
                //           context,
                //         ).pop(
                //           emoji.emoji,
                //         ),
                //         config: Config(
                //           emojiViewConfig: const EmojiViewConfig(
                //             backgroundColor: Colors.transparent,
                //           ),
                //           bottomActionBarConfig: const BottomActionBarConfig(
                //             enabled: false,
                //           ),
                //           categoryViewConfig: CategoryViewConfig(
                //             initCategory: Category.SMILEYS,
                //             backspaceColor: theme.colorScheme.primary,
                //             iconColor: theme.colorScheme.primary.withAlpha(
                //               128,
                //             ),
                //             iconColorSelected: theme.colorScheme.primary,
                //             indicatorColor: theme.colorScheme.primary,
                //             backgroundColor: theme.colorScheme.surface,
                //           ),
                //           skinToneConfig: SkinToneConfig(
                //             dialogBackgroundColor: Color.lerp(
                //               theme.colorScheme.surface,
                //               theme.colorScheme.primaryContainer,
                //               0.75,
                //             )!,
                //             indicatorColor: theme.colorScheme.onSurface,
                //           ),
                //         ),
                //       ),
                //     ),
                //   ),
                // );
                // if (emoji == null) {
                //   return;
                // }
                // if (sentReactions.contains(
                //   emoji,
                // )) {
                //   return;
                // }
                // onSelect(event);

                // await event.room.sendReaction(
                //   event.eventId,
                //   emoji,
                // );
              },
            ),
          ],
        ),
      ),
    );
  }
}
