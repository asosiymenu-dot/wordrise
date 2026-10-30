import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/chat_image_compression.dart';
import '../../core/utils/error_message.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/ios_selection_sheet.dart';
import '../../core/widgets/lesson_picker_sheet.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/api_models.dart';
import '../../services/battle_service.dart';
import '../../services/api_service.dart';
import '../../services/lesson_service.dart';
import '../../services/message_service.dart';
import '../../services/presence_service.dart';
import '../../services/websocket_service.dart';
import '../battle/battle_screen.dart';
import '../profile/public_profile_screen.dart';
import '../../services/audio_haptic_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    required this.active,
    required this.currentUser,
    required this.service,
    required this.battleService,
    required this.lessonService,
    required this.presenceService,
    required this.websocketService,
    this.onUnreadChanged,
    super.key,
  });

  final bool active;
  final UserModel currentUser;
  final MessageService service;
  final BattleService battleService;
  final LessonService lessonService;
  final PresenceService presenceService;
  final WebSocketService websocketService;
  final ValueChanged<int>? onUnreadChanged;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  StreamSubscription? _wsSubscription;
  List<ConversationModel> _conversations = [];
  List<PublicUserModel> _results = [];
  bool _loadingConversations = true;
  bool _searching = false;
  bool _refreshing = false;
  bool _manualRefreshing = false;
  bool _searchActive = false;
  String? _conversationError;
  String? _searchError;
  bool _appForeground = true;
  int _pollFailures = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchFocus.addListener(_handleSearchFocus);
    if (widget.active) {
      unawaited(_loadConversations(initial: true));
    }
    
    _wsSubscription = widget.websocketService.events.listen((event) {
      if (event['type'] == 'new_message' || 
          event['type'] == 'message_updated' || 
          event['type'] == 'messages_read' ||
          event['type'] == 'user_status_changed' ||
          event['type'] == 'typing_status' ||
          event['type'] == 'reconnected') {
        unawaited(_loadConversations(silent: true));
      }
    });
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _loadConversations(
        initial: _conversations.isEmpty,
        silent: _conversations.isNotEmpty,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appForeground = state == AppLifecycleState.resumed;
    if (_appForeground && widget.active) {
      _loadConversations(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _wsSubscription?.cancel();
    _scroll.dispose();
    _searchFocus
      ..removeListener(_handleSearchFocus)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_searchActive) return;
      final view = View.of(context);
      final keyboardHeight = view.viewInsets.bottom / view.devicePixelRatio;
      if (keyboardHeight == 0) _deactivateSearch();
    });
  }

  void _handleSearchFocus() {
    if (_searchFocus.hasFocus && !_searchActive) {
      setState(() => _searchActive = true);
    } else if (!_searchFocus.hasFocus && _searchActive) {
      _clearSearchState();
    }
  }

  void _deactivateSearch() {
    if (_searchFocus.hasFocus) {
      _searchFocus.unfocus();
      return;
    }
    _clearSearchState();
  }

  void _clearSearchState() {
    _debounce?.cancel();
    _search.clear();
    if (!mounted) return;
    setState(() {
      _searchActive = false;
      _results = [];
      _searching = false;
      _searchError = null;
    });
  }

  Future<void> _reload() async {
    if (_manualRefreshing) return;
    AudioHapticService.instance.selectionClick();
    setState(() => _manualRefreshing = true);
    try {
      while (_refreshing && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      await Future.wait([
        _loadConversations(silent: true),
        Future<void>.delayed(const Duration(milliseconds: 480)),
      ]);
    } finally {
      if (mounted) setState(() => _manualRefreshing = false);
    }
  }

  Future<void> _loadConversations({
    bool silent = false,
    bool initial = false,
  }) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent) {
      setState(() {
        _loadingConversations = initial || _conversations.isEmpty;
        _conversationError = null;
      });
    }
    try {
      final conversations = await widget.service.conversations();
      if (!mounted) return;
      _pollFailures = 0;
      if (!_conversationListsEquivalent(_conversations, conversations) ||
          _loadingConversations ||
          _conversationError != null) {
        setState(() {
          _conversations = conversations;
          _loadingConversations = false;
          _conversationError = null;
        });
      }
      for (final conversation in conversations) {
        final message = conversation.lastMessage;
        if (message == null ||
            message.senderId == widget.currentUser.id ||
            message.deliveredAt != null) {
          continue;
        }
        unawaited(
          widget.service
              .markDelivered(
                userId: conversation.user.id,
                upToMessageId: message.id,
              )
              .catchError((Object _) {}),
        );
      }
      widget.onUnreadChanged?.call(
        conversations.fold<int>(
          0,
          (total, conversation) => total + conversation.unreadCount,
        ),
      );
    } on Object catch (error) {
      _pollFailures = (_pollFailures + 1).clamp(0, 3);
      if (!silent && mounted) {
        setState(() {
          _conversationError = userFacingError(context, error);
          _loadingConversations = false;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _searchError = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _searching = true;
        _searchError = null;
      });
      try {
        final users = await widget.service.searchUsers(query);
        if (!mounted) return;
        setState(() => _results = users);
      } on Object catch (error) {
        if (mounted) {
          setState(() => _searchError = userFacingError(context, error));
        }
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _openChat(PublicUserModel user) async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            currentUser: widget.currentUser,
            otherUser: user,
            service: widget.service,
            battleService: widget.battleService,
            lessonService: widget.lessonService,
            presenceService: widget.presenceService,
            websocketService: widget.websocketService,
          ),
        ),
      );
    } finally {
      if (mounted && widget.active) {
        _reload();
      }
    }
  }

  Future<void> _showBroadcastSheet() async {
    final controller = TextEditingController();
    final sentCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var sending = false;
        String? error;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final l10n = context.l10n;
            Future<void> submit() async {
              final text = controller.text.trim();
              if (text.isEmpty || sending) return;
              setSheetState(() {
                sending = true;
                error = null;
              });
              try {
                final count = await widget.service.broadcast(text);
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(count);
                }
              } on Object catch (submitError) {
                if (sheetContext.mounted) {
                  setSheetState(() {
                    error = userFacingError(sheetContext, submitError);
                    sending = false;
                  });
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
                ),
                child: GlassCard(
                  padding: const EdgeInsets.all(18),
                  borderRadius: 28,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('messages.broadcast'),
                        style: AppTextStyles.titleFor(context),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.t('messages.broadcastSubtitle'),
                        style: AppTextStyles.captionFor(context),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          hintText: l10n.t('messages.broadcastHint'),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        ErrorStateView(message: error!),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: sending ? null : submit,
                          icon: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.campaign_rounded),
                          label: Text(l10n.t('messages.broadcastSend')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();

    if (sentCount != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.f('messages.broadcastSent', {
              'count': sentCount.toString(),
            }),
          ),
        ),
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GradientBackground(
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t('messages.title'),
                  style: AppTextStyles.displayFor(context),
                ),
              ),
              if (widget.currentUser.role == 'admin') ...[
                IconButton.filledTonal(
                  tooltip: l10n.t('messages.broadcast'),
                  onPressed: _showBroadcastSheet,
                  icon: const Icon(Icons.campaign_rounded),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t('messages.subtitle'),
            style: AppTextStyles.captionFor(context),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CupertinoSearchTextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  placeholder: l10n.t('messages.search'),
                  onTap: () {
                    if (!_searchActive) setState(() => _searchActive = true);
                  },
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _searchFocus.unfocus(),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: _searchActive
                    ? CupertinoButton(
                        padding: const EdgeInsets.only(left: 12),
                        onPressed: _deactivateSearch,
                        child: Text(l10n.t('common.cancel')),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (_searchActive && _searching) ...[
            const SizedBox(height: 12),
            LoadingStateView(message: l10n.t('messages.searching')),
          ] else if (_searchActive && _searchError != null) ...[
            const SizedBox(height: 12),
            ErrorStateView(message: _searchError!),
          ] else if (_searchActive && _results.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.t('messages.found'),
              style: AppTextStyles.sectionFor(context),
            ),
            const SizedBox(height: 10),
            for (final user in _results) ...[
              _UserTile(user: user, onTap: () => _openChat(user)),
              const SizedBox(height: 10),
            ],
          ],
          if (!_searchActive) ...[
            const SizedBox(height: 16),
            Text(
              l10n.t('messages.recent'),
              style: AppTextStyles.sectionFor(context),
            ),
            const SizedBox(height: 10),
            if (_loadingConversations)
              const LoadingStateView()
            else if (_conversationError != null)
              ErrorStateView(message: _conversationError!, onRetry: _reload)
            else if (_conversations.isEmpty)
              EmptyStateView(
                icon: Icons.chat_bubble_outline_rounded,
                message: l10n.t('messages.empty'),
              )
            else
              for (final conversation in _conversations) ...[
                _ConversationTile(
                  conversation: conversation,
                  currentUserId: widget.currentUser.id,
                  onTap: () => _openChat(conversation.user),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ],
      ),
    );
  }
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    required this.currentUser,
    required this.otherUser,
    required this.service,
    required this.battleService,
    required this.lessonService,
    required this.presenceService,
    required this.websocketService,
    super.key,
  });

  final UserModel currentUser;
  final PublicUserModel otherUser;
  final MessageService service;
  final BattleService battleService;
  final LessonService lessonService;
  final PresenceService presenceService;
  final WebSocketService websocketService;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen>
    with WidgetsBindingObserver {
  final _message = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final _imagePicker = ImagePicker();
  StreamSubscription? _wsSubscription;
  Timer? _typingStopTimer;
  Timer? _typingKeepAliveTimer;
  List<MessageModel> _messages = [];
  bool _loadingThread = true;
  bool _refreshing = false;
  bool _sending = false;
  bool _loadingOlder = false;
  bool _hasMore = true;
  bool _appForeground = true;
  bool _preparingBattle = false;
  bool _typingDesired = false;
  bool _typingLastSent = false;
  bool _typingRequestInFlight = false;
  bool _typingRefreshPending = false;
  int _pollFailures = 0;
  int _lastReadAck = 0;
  String? _syncToken;
  MessageModel? _replyingTo;
  MessageModel? _editingMessage;
  _PreparedChatImage? _preparedImage;
  double _uploadProgress = 0;
  PresenceModel? _presence;
  int? _highlightedMessageId;
  final Set<int> _updatingInvites = {};
  final Map<int, GlobalKey> _messageKeys = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_handleScroll);
    _message.addListener(_handleComposerChanged);
    _inputFocus.addListener(_handleComposerChanged);
    
    // Initial load
    unawaited(_loadThread(initial: true, follow: true));
    unawaited(_loadPresenceInitial());
    
    _wsSubscription = widget.websocketService.events.listen((event) {
      if (!mounted) return;
      final type = event['type'] as String?;
      
      if (type == 'new_message' || 
          type == 'message_updated' || 
          type == 'messages_read' ||
          type == 'reconnected') {
        unawaited(_loadThread(silent: true));
      } else if (type == 'user_status_changed' || type == 'typing_status') {
        unawaited(_loadPresenceInitial());
      }
    });
  }

  Future<void> _loadPresenceInitial() async {
    try {
      final presence = await widget.presenceService.status(widget.otherUser.id);
      if (mounted) {
        setState(() => _presence = presence);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsSubscription?.cancel();
    _message.removeListener(_handleComposerChanged);
    _inputFocus.removeListener(_handleComposerChanged);
    _stopTyping();
    _scroll
      ..removeListener(_handleScroll)
      ..dispose();
    _message.dispose();
    _inputFocus.dispose();
    _cleanupPreparedImage();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appForeground = state == AppLifecycleState.resumed;
    if (_appForeground) {
      _loadThread(silent: true);
      _loadPresenceInitial();
    } else {
      _stopTyping();
    }
  }

  void _reload() => unawaited(_loadThread(follow: true));

  void _handleComposerChanged() {
    final shouldType =
        _appForeground &&
        _inputFocus.hasFocus &&
        _message.text.trim().isNotEmpty;
    if (!shouldType) {
      _stopTyping();
      return;
    }

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 2), _stopTyping);
    if (_typingDesired) return;

    _queueTyping(true, refresh: true);
    _typingKeepAliveTimer?.cancel();
    _typingKeepAliveTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_typingDesired && _appForeground) {
        _queueTyping(true, refresh: true);
      }
    });
  }

  void _stopTyping() {
    _typingStopTimer?.cancel();
    _typingStopTimer = null;
    _typingKeepAliveTimer?.cancel();
    _typingKeepAliveTimer = null;
    if (_typingDesired || _typingLastSent) _queueTyping(false);
  }

  void _queueTyping(bool value, {bool refresh = false}) {
    _typingDesired = value;
    _typingRefreshPending = value && refresh;
    unawaited(_flushTyping());
  }

  Future<void> _flushTyping() async {
    if (_typingRequestInFlight) return;
    _typingRequestInFlight = true;
    var failed = false;
    try {
      while (true) {
        final desired = _typingDesired;
        final shouldSend =
            desired != _typingLastSent || (desired && _typingRefreshPending);
        if (!shouldSend) break;
        if (desired) _typingRefreshPending = false;
        try {
          await widget.presenceService.setTyping(
            receiverId: widget.otherUser.id,
            isTyping: desired,
          );
          _typingLastSent = desired;
        } on Object {
          failed = true;
          break;
        }
      }
    } finally {
      _typingRequestInFlight = false;
      final pending =
          _typingDesired != _typingLastSent ||
          (_typingDesired && _typingRefreshPending);
      if (!failed && pending) unawaited(_flushTyping());
    }
  }

  void _handleScroll() {
    if (_scroll.hasClients && _scroll.position.pixels < 180) {
      unawaited(_loadOlder());
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _messages.isEmpty) return;
    final firstServerMessage = _messages.where((message) => message.id > 0);
    if (firstServerMessage.isEmpty) return;
    _loadingOlder = true;
    final previousExtent = _scroll.hasClients
        ? _scroll.position.maxScrollExtent
        : 0.0;
    final previousOffset = _scroll.hasClients ? _scroll.offset : 0.0;
    try {
      final page = await widget.service.threadPage(
        widget.otherUser.id,
        beforeId: firstServerMessage.first.id,
        limit: 50,
      );
      if (!mounted) return;
      final merged = mergeMessageLists(_messages, page.messages);
      setState(() {
        _messages = merged;
        _hasMore = page.hasMore;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final addedExtent = _scroll.position.maxScrollExtent - previousExtent;
        _scroll.jumpTo(
          (previousOffset + addedExtent).clamp(
            _scroll.position.minScrollExtent,
            _scroll.position.maxScrollExtent,
          ),
        );
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = userFacingError(context, error));
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> _loadThread({
    bool silent = false,
    bool initial = false,
    bool follow = false,
  }) async {
    if (_refreshing || !_appForeground) return;
    _refreshing = true;
    final shouldFollow = follow || _isNearBottom;
    if (!silent && mounted) {
      setState(() {
        _loadingThread = initial || _messages.isEmpty;
        _error = null;
      });
    }
    try {
      final serverMessages = _messages.where((message) => message.id > 0);
      final hasPendingInvite = _messages.any(
        (message) => message.battleInvite?.pending ?? false,
      );
      final incremental =
          silent && serverMessages.isNotEmpty && !hasPendingInvite;
      final lastId = incremental ? serverMessages.last.id : 0;
      final page = await widget.service.threadPage(
        widget.otherUser.id,
        afterId: lastId,
        updatedSince: incremental ? _syncToken : null,
        limit: 50,
      );
      if (!mounted) return;
      _pollFailures = 0;
      _syncToken = page.syncToken ?? _syncToken;
      final localPending = _messages.where((message) => message.id < 0);
      final merged = silent
          ? mergeMessageLists(_messages, page.messages)
          : mergeMessageLists(localPending, page.messages);
      if (!messageListsEquivalent(_messages, merged) ||
          _loadingThread ||
          _error != null) {
        setState(() {
          _messages = merged;
          _loadingThread = false;
          _error = null;
          if (!silent) _hasMore = page.hasMore;
        });
      }
      unawaited(_acknowledgeIncoming(merged));
      if (shouldFollow && page.messages.isNotEmpty) {
        _scrollToBottom(animated: !initial);
      }
    } on Object catch (error) {
      _pollFailures = (_pollFailures + 1).clamp(0, 4);
      if (!silent && mounted) {
        setState(() {
          _error = userFacingError(context, error);
          _loadingThread = false;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _acknowledgeIncoming(List<MessageModel> messages) async {
    var upToId = 0;
    for (final message in messages) {
      if (message.senderId == widget.otherUser.id && message.id > upToId) {
        upToId = message.id;
      }
    }
    if (upToId <= _lastReadAck) return;
    try {
      await widget.service.markDelivered(
        userId: widget.otherUser.id,
        upToMessageId: upToId,
      );
      await widget.service.markRead(
        userId: widget.otherUser.id,
        upToMessageId: upToId,
      );
      _lastReadAck = upToId;
    } on Object {
      // The next successful poll retries the acknowledgement.
    }
  }

  bool get _isNearBottom {
    if (!_scroll.hasClients) return true;
    final position = _scroll.position;
    return position.maxScrollExtent - position.pixels < 90;
  }

  void _scrollToBottom({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animated) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (_sending) return;
    _stopTyping();
    if (_editingMessage != null) {
      await _saveEdit(text);
      return;
    }
    if (_preparedImage != null) {
      await _sendImage(_preparedImage!);
      return;
    }
    if (text.isEmpty) return;

    final clientMessageId = _newClientMessageId();
    final reply = _replyingTo;
    final pending = MessageModel(
      id: -DateTime.now().microsecondsSinceEpoch,
      senderId: widget.currentUser.id,
      receiverId: widget.otherUser.id,
      clientMessageId: clientMessageId,
      body: text,
      createdAt: DateTime.now().toIso8601String(),
      replyToMessageId: reply?.id,
      replyTo: reply == null ? null : _replyPreview(reply),
      localState: MessageSendState.sending,
    );
    setState(() {
      _sending = true;
      _error = null;
      _messages = mergeMessageLists(_messages, [pending]);
      _replyingTo = null;
    });
    _message.clear();
    _scrollToBottom(animated: true);
    try {
      final sent = await widget.service.send(
        receiverId: widget.otherUser.id,
        body: text,
        clientMessageId: clientMessageId,
        replyToMessageId: reply?.id,
      );
      if (!mounted) return;
      setState(() => _messages = mergeMessageLists(_messages, [sent]));
      unawaited(_loadThread(silent: true));
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = userFacingError(context, error);
          _replacePending(
            clientMessageId,
            (message) => message.copyWith(localState: MessageSendState.failed),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveEdit(String text) async {
    final editing = _editingMessage;
    if (editing == null || text.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final updated = await widget.service.update(
        messageId: editing.id,
        body: text,
      );
      if (!mounted) return;
      setState(() {
        _messages = mergeMessageLists(_messages, [updated]);
        _editingMessage = null;
      });
      _message.clear();
    } on Object catch (error) {
      if (mounted) setState(() => _error = userFacingError(context, error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    if (_sending || _editingMessage != null) return;
    final tooLargeMessage = context.l10n.t('messages.imageTooLarge');
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final sourceBytes = await picked.readAsBytes();
      Uint8List? compressed;
      for (final preset in chatImageCompressionPresets) {
        final result = await FlutterImageCompress.compressWithList(
          sourceBytes,
          minWidth: preset.maxSide,
          minHeight: preset.maxSide,
          quality: preset.quality,
          format: CompressFormat.jpeg,
          autoCorrectionAngle: true,
          keepExif: false,
        );
        if (result.isEmpty) continue;
        compressed = result;
        if (result.length <= chatImageMaxBytes) break;
      }
      if ((compressed == null || compressed.length > chatImageMaxBytes) &&
          sourceBytes.length <= chatImageMaxBytes) {
        compressed = sourceBytes;
      }
      if (compressed == null || compressed.length > chatImageMaxBytes) {
        throw ApiException(tooLargeMessage, type: ApiExceptionType.badResponse);
      }
      if (!mounted) return;
      _cleanupPreparedImage();
      setState(() {
        _preparedImage = _PreparedChatImage(
          bytes: compressed!,
          filename:
              'wordrise_chat_${DateTime.now().microsecondsSinceEpoch}.jpg',
          mimeType: compressed.length == sourceBytes.length
              ? _imageMimeType(picked)
              : 'image/jpeg',
        );
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = userFacingError(context, error));
    }
  }

  Future<void> _sendImage(
    _PreparedChatImage image, {
    MessageModel? retry,
  }) async {
    if (_sending && retry == null) return;
    final clientMessageId = retry?.clientMessageId ?? _newClientMessageId();
    final reply = retry == null ? _replyingTo : null;
    final caption = retry?.body ?? _message.text.trim();
    final pending =
        retry?.copyWith(localState: MessageSendState.sending) ??
        MessageModel(
          id: -DateTime.now().microsecondsSinceEpoch,
          senderId: widget.currentUser.id,
          receiverId: widget.otherUser.id,
          clientMessageId: clientMessageId,
          body: caption,
          type: 'image',
          createdAt: DateTime.now().toIso8601String(),
          replyToMessageId: reply?.id,
          replyTo: reply == null ? null : _replyPreview(reply),
          attachment: MessageAttachmentModel(
            url: '',
            thumbnailUrl: '',
            width: 0,
            height: 0,
            sizeBytes: image.bytes.length,
            mimeType: image.mimeType,
            localBytes: image.bytes,
          ),
          localState: MessageSendState.sending,
        );
    setState(() {
      _sending = true;
      _uploadProgress = 0;
      _error = null;
      _preparedImage = null;
      _replyingTo = null;
      _messages = mergeMessageLists(_messages, [pending]);
    });
    if (retry == null) _message.clear();
    _scrollToBottom(animated: true);
    try {
      final sent = await widget.service.sendImage(
        receiverId: widget.otherUser.id,
        bytes: image.bytes,
        filename: image.filename,
        mimeType: image.mimeType,
        clientMessageId: clientMessageId,
        body: caption,
        replyToMessageId: retry?.replyToMessageId ?? reply?.id,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = progress;
            _replacePending(
              clientMessageId,
              (message) => message.copyWith(uploadProgress: progress),
            );
          });
        },
      );
      if (!mounted) return;
      setState(() => _messages = mergeMessageLists(_messages, [sent]));
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = userFacingError(context, error);
          _replacePending(
            clientMessageId,
            (message) => message.copyWith(localState: MessageSendState.failed),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<void> _retryMessage(MessageModel message) async {
    final clientId = message.clientMessageId;
    if (clientId == null || _sending) return;
    if (message.type == 'image') {
      final attachment = message.attachment;
      final bytes = attachment?.localBytes;
      if (bytes != null && bytes.isNotEmpty) {
        await _sendImage(
          _PreparedChatImage(
            bytes: bytes,
            filename:
                'wordrise_retry_${DateTime.now().microsecondsSinceEpoch}.jpg',
            mimeType: attachment!.mimeType,
          ),
          retry: message,
        );
      }
      return;
    }
    setState(() {
      _sending = true;
      _replacePending(
        clientId,
        (candidate) => candidate.copyWith(localState: MessageSendState.sending),
      );
    });
    try {
      final sent = await widget.service.send(
        receiverId: widget.otherUser.id,
        body: message.body,
        clientMessageId: clientId,
        replyToMessageId: message.replyToMessageId,
      );
      if (mounted) {
        setState(() => _messages = mergeMessageLists(_messages, [sent]));
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = userFacingError(context, error);
          _replacePending(
            clientId,
            (candidate) =>
                candidate.copyWith(localState: MessageSendState.failed),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _replacePending(
    String clientMessageId,
    MessageModel Function(MessageModel message) update,
  ) {
    _messages = [
      for (final message in _messages)
        if (message.clientMessageId == clientMessageId)
          update(message)
        else
          message,
    ];
  }

  String _newClientMessageId() =>
      'm${widget.currentUser.id}_${DateTime.now().microsecondsSinceEpoch}';

  MessageReplyModel _replyPreview(MessageModel message) {
    return MessageReplyModel(
      id: message.id,
      senderId: message.senderId,
      senderName: message.senderId == widget.currentUser.id
          ? widget.currentUser.name
          : widget.otherUser.name,
      type: message.type,
      body: message.body,
      deleted: message.deletedForEveryone,
      attachment: message.attachment,
    );
  }

  String _replyPreviewText(BuildContext context, MessageModel message) {
    if (message.deletedForEveryone) {
      return context.l10n.t('messages.originalDeleted');
    }
    if (message.type == 'image') return context.l10n.t('messages.photo');
    return message.body;
  }

  void _cleanupPreparedImage() {
    _preparedImage = null;
  }

  void _removePreparedImage() {
    if (_preparedImage == null) return;
    setState(() => _preparedImage = null);
  }

  void _cancelComposerMode() {
    _cleanupPreparedImage();
    _message.clear();
    setState(() {
      _replyingTo = null;
      _editingMessage = null;
    });
  }

  void _beginReply(MessageModel message) {
    setState(() {
      _replyingTo = message;
      _editingMessage = null;
    });
    _inputFocus.requestFocus();
  }

  void _beginEdit(MessageModel message) {
    _cleanupPreparedImage();
    _message.text = message.body;
    _message.selection = TextSelection.collapsed(offset: message.body.length);
    setState(() {
      _editingMessage = message;
      _replyingTo = null;
    });
    _inputFocus.requestFocus();
  }

  Future<void> _showMessageActions(MessageModel message) async {
    if (message.deletedForEveryone || message.id < 0) return;
    final mine = message.senderId == widget.currentUser.id;
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.l10n.t('messages.actions')),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('reply'),
            child: Text(context.l10n.t('messages.reply')),
          ),
          if (message.body.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('copy'),
              child: Text(context.l10n.t('messages.copy')),
            ),
          if (mine && message.canEdit)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('edit'),
              child: Text(context.l10n.t('common.edit')),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('delete'),
            child: Text(context.l10n.t('common.delete')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.t('common.cancel')),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'reply':
        _beginReply(message);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.body));
      case 'edit':
        _beginEdit(message);
      case 'delete':
        await _showDeleteOptions(message);
    }
  }

  Future<void> _showDeleteOptions(MessageModel message) async {
    final mine = message.senderId == widget.currentUser.id;
    final mode = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.l10n.t('messages.deleteTitle')),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('for_me'),
            child: Text(context.l10n.t('messages.deleteForMe')),
          ),
          if (mine && message.canDeleteForEveryone)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop('for_everyone'),
              child: Text(context.l10n.t('messages.deleteForEveryone')),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.t('common.cancel')),
        ),
      ),
    );
    if (mode == null) return;
    try {
      final updated = await widget.service.deleteMessage(
        messageId: message.id,
        mode: mode,
      );
      if (!mounted) return;
      setState(() {
        _messages = mode == 'for_me'
            ? _messages.where((item) => item.id != message.id).toList()
            : updated == null
            ? _messages
            : mergeMessageLists(_messages, [updated]);
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = userFacingError(context, error));
    }
  }

  Future<void> _scrollToMessage(int messageId) async {
    var index = _messages.indexWhere((message) => message.id == messageId);
    var attempts = 0;
    while (index < 0 && _hasMore && attempts < 8) {
      await _loadOlder();
      index = _messages.indexWhere((message) => message.id == messageId);
      attempts++;
    }
    if (!mounted || index < 0) return;
    final keyContext = _messageKeys[messageId]?.currentContext;
    if (keyContext != null && keyContext.mounted) {
      await Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: .35,
      );
    } else if (_scroll.hasClients && _messages.length > 1) {
      final target =
          _scroll.position.maxScrollExtent * (index / (_messages.length - 1));
      await _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    setState(() => _highlightedMessageId = messageId);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted && _highlightedMessageId == messageId) {
      setState(() => _highlightedMessageId = null);
    }
  }

  Future<void> _offerBattle() async {
    if (_preparingBattle) return;
    setState(() {
      _preparingBattle = true;
      _error = null;
    });
    try {
      final lessons = await widget.lessonService.all();
      if (!mounted) return;
      final sent = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _BattleInviteSheet(
          lessons: lessons,
          receiver: widget.otherUser,
          service: widget.battleService,
        ),
      );
      if (sent == true) {
        await _loadThread(silent: true, follow: true);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = userFacingError(context, error));
      }
    } finally {
      if (mounted) setState(() => _preparingBattle = false);
    }
  }

  Future<void> _respondToInvite(BattleInviteModel invite, String action) async {
    if (!_updatingInvites.add(invite.id)) return;
    setState(() => _error = null);
    try {
      final result = await widget.battleService.respond(
        inviteId: invite.id,
        action: action,
      );
      await _loadThread(silent: true, follow: true);
      if (!mounted) return;
      if (result.battle != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BattleScreen(
              service: widget.battleService,
              initialBattle: result.battle!,
            ),
          ),
        );
        await _loadThread(silent: true, follow: true);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = userFacingError(context, error));
      }
    } finally {
      _updatingInvites.remove(invite.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _openBattle(int battleId) async {
    try {
      final battle = await widget.battleService.state(battleId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BattleScreen(
            service: widget.battleService,
            initialBattle: battle,
          ),
        ),
      );
      await _loadThread(silent: true, follow: true);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = userFacingError(context, error));
      }
    }
  }

  PresenceModel get _effectivePresence {
    final current = _presence;
    if (current != null) return current;
    return PresenceModel(
      userId: widget.otherUser.id,
      isOnline: widget.otherUser.isOnline,
      lastSeenAt: widget.otherUser.localLastSeenAt,
    );
  }

  String _presenceLabel(BuildContext context) {
    final presence = _effectivePresence;
    if (presence.isTyping) return context.l10n.t('messages.typing');
    if (presence.isOnline) return context.l10n.t('messages.online');
    final seen = presence.lastSeenAt;
    if (seen == null) return context.l10n.t('messages.offline');
    final now = DateTime.now();
    final time = DateFormat('HH:mm').format(seen);
    if (_sameLocalDay(seen, now)) {
      return context.l10n.f('messages.lastSeenToday', {'time': time});
    }
    if (_sameLocalDay(seen, now.subtract(const Duration(days: 1)))) {
      return context.l10n.f('messages.lastSeenYesterday', {'time': time});
    }
    return context.l10n.f('messages.lastSeenDate', {
      'date': DateFormat('dd.MM.yyyy HH:mm').format(seen),
    });
  }

  Widget _buildMessageItem(BuildContext context, int index) {
    final item = _messages[index];
    final mine = item.senderId == widget.currentUser.id;
    final previous = index > 0 ? _messages[index - 1] : null;
    final showDay =
        previous == null ||
        !_sameLocalDay(previous.localCreatedAt, item.localCreatedAt);
    final messageKey = _messageKeys.putIfAbsent(item.id, GlobalKey.new);
    late final Widget content;
    if (item.type == 'battle_invite' && item.battleInvite != null) {
      final invite = item.battleInvite!;
      content = _BattleInviteCard(
        invite: invite,
        mine: mine,
        updating: _updatingInvites.contains(invite.id),
        onAction: (action) => _respondToInvite(invite, action),
        onOpen: () => _openBattle(invite.battleId),
      );
    } else if (item.type == 'battle_result') {
      content = _BattleResultCard(
        message: item,
        mine: mine,
        onOpen: () => _openBattle(_asInt(item.metadata['battle_id'])),
      );
    } else {
      content = _MessageBubble(
        message: item,
        mine: mine,
        highlighted: _highlightedMessageId == item.id,
        onLongPress: () => _showMessageActions(item),
        onReplyTap: item.replyToMessageId == null
            ? null
            : () => _scrollToMessage(item.replyToMessageId!),
        onRetry: item.sendState == MessageSendState.failed
            ? () => _retryMessage(item)
            : null,
        onOpenImage: item.type == 'image' ? () => _openImageViewer(item) : null,
      );
    }

    return Column(
      key: messageKey,
      children: [
        if (showDay)
          _DayDivider(label: _formatDayLabel(context, item.localCreatedAt)),
        TweenAnimationBuilder<double>(
          key: ValueKey('message-animation-${item.id}'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - value)),
              child: child,
            ),
          ),
          child: content,
        ),
        if (item.isSystem)
          Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: Text(
                _formatMessageTime(item),
                style: AppTextStyles.captionFor(context).copyWith(fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openImageViewer(MessageModel message) async {
    final attachment = message.attachment;
    if (attachment == null) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: _ImageViewer(attachment: attachment),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final presence = _effectivePresence;
    final presenceColor = presence.isTyping
        ? AppColors.blue
        : presence.isOnline
        ? AppColors.green
        : AppColors.textMuted(context);
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(CupertinoIcons.back),
                    ),
                    UserAvatar(
                      name: widget.otherUser.name,
                      avatarUrl: widget.otherUser.avatar,
                      size: 42,
                      online: presence.isOnline,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.otherUser.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.sectionFor(context),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: presenceColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _presenceLabel(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.captionFor(context)
                                      .copyWith(
                                        color: presenceColor,
                                        fontSize: 12,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.t('profile.viewProfile'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicProfileScreen(user: widget.otherUser),
                        ),
                      ),
                      icon: const Icon(Icons.info_outline_rounded),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loadingThread
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: const [LoadingStateView()],
                    )
                  : _error != null && _messages.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        ErrorStateView(message: _error!, onRetry: _reload),
                      ],
                    )
                  : _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: EmptyStateView(
                          icon: Icons.waving_hand_outlined,
                          message: l10n.t('messages.threadEmpty'),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                      itemCount: _messages.length + (_loadingOlder ? 1 : 0),
                      findChildIndexCallback: (key) {
                        if (key is! ValueKey<String>) return null;
                        final value = key.value;
                        if (!value.startsWith('message-')) return null;
                        final id = int.tryParse(value.substring(8));
                        final index = _messages.indexWhere(
                          (message) => message.id == id,
                        );
                        if (index < 0) return null;
                        return index + (_loadingOlder ? 1 : 0);
                      },
                      itemBuilder: (context, index) {
                        if (_loadingOlder && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(child: CupertinoActivityIndicator()),
                          );
                        }
                        final messageIndex = index - (_loadingOlder ? 1 : 0);
                        final message = _messages[messageIndex];
                        return KeyedSubtree(
                          key: ValueKey('message-${message.id}'),
                          child: _buildMessageItem(context, messageIndex),
                        );
                      },
                    ),
            ),
            if (_error != null && _messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: ErrorStateView(message: _error!),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: GlassCard(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  borderRadius: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_editingMessage != null || _replyingTo != null)
                        _ComposerContextPanel(
                          title: _editingMessage != null
                              ? l10n.t('messages.editing')
                              : l10n.t('messages.replying'),
                          preview:
                              _editingMessage?.body ??
                              _replyPreviewText(context, _replyingTo!),
                          onCancel: _cancelComposerMode,
                        ),
                      if (_preparedImage != null)
                        _ImageComposerPreview(
                          image: _preparedImage!,
                          progress: _uploadProgress,
                          onRemove: _removePreparedImage,
                        ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: l10n.t('battle.offer'),
                            onPressed: _preparingBattle ? null : _offerBattle,
                            color: AppColors.purple,
                            visualDensity: VisualDensity.compact,
                            icon: _preparingBattle
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sports_martial_arts_rounded),
                          ),
                          IconButton(
                            tooltip: l10n.t('messages.attachImage'),
                            onPressed: _sending ? null : _pickImage,
                            color: AppColors.blue,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(CupertinoIcons.photo),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _message,
                              focusNode: _inputFocus,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 1000,
                              buildCounter:
                                  (
                                    _, {
                                    required currentLength,
                                    required isFocused,
                                    required maxLength,
                                  }) => null,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: _editingMessage != null
                                    ? l10n.t('messages.editHint')
                                    : l10n.t('messages.write'),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filled(
                            tooltip: l10n.t('messages.sendMessage'),
                            onPressed: _sending ? null : _send,
                            icon: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _editingMessage != null
                                        ? CupertinoIcons.check_mark
                                        : CupertinoIcons.arrow_up,
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  final ConversationModel conversation;
  final int currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final message = conversation.lastMessage;
    final prefix = message?.senderId == currentUserId
        ? '${context.l10n.t('messages.you')}: '
        : '';
    final preview = message == null
        ? ''
        : message.deletedForEveryone
        ? context.l10n.t('messages.deleted')
        : message.type == 'image'
        ? context.l10n.t('messages.photo')
        : message.body;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          UserAvatar(
            name: conversation.user.name,
            avatarUrl: conversation.user.avatar,
            online: conversation.user.isOnline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.sectionFor(
                          context,
                        ).copyWith(fontSize: 16),
                      ),
                    ),
                    if (message != null)
                      Text(
                        _formatConversationTime(context, message),
                        style: AppTextStyles.captionFor(
                          context,
                        ).copyWith(fontSize: 11),
                      ),
                    if (conversation.unreadCount > 0) ...[
                      const SizedBox(width: 6),
                      _UnreadDot(conversation),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$prefix$preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionFor(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot(this.conversation);

  final ConversationModel conversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${conversation.unreadCount}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});

  final PublicUserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          UserAvatar(
            name: user.name,
            avatarUrl: user.avatar,
            online: user.isOnline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: AppTextStyles.sectionFor(context)),
                if (user.username.isNotEmpty)
                  Text(
                    '@${user.username}',
                    style: AppTextStyles.captionFor(
                      context,
                    ).copyWith(color: AppColors.purple),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.blue),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.highlighted,
    required this.onLongPress,
    required this.onReplyTap,
    required this.onRetry,
    required this.onOpenImage,
  });

  final MessageModel message;
  final bool mine;
  final bool highlighted;
  final VoidCallback onLongPress;
  final VoidCallback? onReplyTap;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenImage;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = mine
        ? AppColors.blue.withValues(alpha: .92)
        : Colors.white.withValues(alpha: AppColors.isDark(context) ? .10 : .62);
    final textColor = mine ? Colors.white : AppColors.textPrimary(context);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .78,
          ),
          margin: const EdgeInsets.only(bottom: 9),
          padding: EdgeInsets.all(message.type == 'image' ? 5 : 11),
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.gold.withValues(alpha: .38)
                : bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 6),
              bottomRight: Radius.circular(mine ? 6 : 18),
            ),
            border: highlighted
                ? Border.all(color: AppColors.gold, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.replyTo != null)
                _ReplyPreview(
                  reply: message.replyTo!,
                  mine: mine,
                  onTap: onReplyTap,
                ),
              if (message.deletedForEveryone)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.delete,
                        size: 15,
                        color: textColor.withValues(alpha: .72),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          context.l10n.t('messages.deleted'),
                          style: AppTextStyles.captionFor(context).copyWith(
                            color: textColor.withValues(alpha: .76),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (message.type == 'image' && message.attachment != null)
                  _MessageImage(
                    attachment: message.attachment!,
                    progress: message.uploadProgress,
                    onTap: onOpenImage,
                  ),
                if (message.body.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      message.type == 'image' ? 7 : 3,
                      message.type == 'image' ? 7 : 2,
                      message.type == 'image' ? 7 : 3,
                      2,
                    ),
                    child: Text(
                      message.body,
                      style: AppTextStyles.bodyFor(
                        context,
                      ).copyWith(color: textColor, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
              Padding(
                padding: EdgeInsets.fromLTRB(
                  message.type == 'image' ? 7 : 3,
                  4,
                  message.type == 'image' ? 5 : 1,
                  0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (message.editedAt != null) ...[
                      Text(
                        context.l10n.t('messages.edited'),
                        style: TextStyle(
                          color: textColor.withValues(alpha: .68),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      _formatMessageTime(message),
                      style: TextStyle(
                        color: textColor.withValues(alpha: .72),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 5),
                      _MessageStatusIcon(
                        state: message.sendState,
                        onBlue: mine,
                      ),
                    ],
                  ],
                ),
              ),
              if (message.sendState == MessageSendState.failed && mine)
                CupertinoButton(
                  padding: const EdgeInsets.only(top: 5, left: 3, right: 3),
                  minimumSize: const Size(0, 28),
                  onPressed: onRetry,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_circle_fill,
                        color: AppColors.softRed,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        context.l10n.t('messages.retrySend'),
                        style: const TextStyle(
                          color: AppColors.softRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon({required this.state, required this.onBlue});

  final MessageSendState state;
  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    final base = onBlue
        ? Colors.white.withValues(alpha: .78)
        : AppColors.textMuted(context);
    return Icon(
      switch (state) {
        MessageSendState.sending => CupertinoIcons.clock,
        MessageSendState.sent => CupertinoIcons.check_mark,
        MessageSendState.delivered || MessageSendState.read => Icons.done_all,
        MessageSendState.failed => CupertinoIcons.exclamationmark_circle_fill,
      },
      size: state == MessageSendState.sent ? 13 : 15,
      color: switch (state) {
        MessageSendState.read => const Color(0xFF79F2D0),
        MessageSendState.failed => AppColors.softRed,
        _ => base,
      },
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.reply,
    required this.mine,
    required this.onTap,
  });

  final MessageReplyModel reply;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = mine ? Colors.white : AppColors.textPrimary(context);
    final preview = reply.deleted
        ? context.l10n.t('messages.originalDeleted')
        : reply.type == 'image'
        ? context.l10n.t('messages.photo')
        : reply.body;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: mine ? .12 : .07),
          borderRadius: BorderRadius.circular(11),
          border: Border(
            left: BorderSide(
              color: mine ? const Color(0xFFB8F4FF) : AppColors.purple,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reply.senderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground.withValues(alpha: .75),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageImage extends StatelessWidget {
  const _MessageImage({
    required this.attachment,
    required this.progress,
    required this.onTap,
  });

  final MessageAttachmentModel attachment;
  final double progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = attachment.aspectRatio.clamp(.62, 1.8).toDouble();
    final localBytes = attachment.localBytes;
    final image = localBytes != null
        ? Image.memory(
            localBytes,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          )
        : _ProgressiveMessageImage(
            thumbnailUrl: attachment.thumbnailUrl,
            fullUrl: attachment.url,
          );
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (progress > 0 && progress < 1)
                ColoredBox(
                  color: Colors.black.withValues(alpha: .32),
                  child: Center(
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressiveMessageImage extends StatelessWidget {
  const _ProgressiveMessageImage({
    required this.thumbnailUrl,
    required this.fullUrl,
  });

  final String thumbnailUrl;
  final String fullUrl;

  @override
  Widget build(BuildContext context) {
    final thumbnail = Image.network(
      thumbnailUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, synchronouslyLoaded) {
        if (synchronouslyLoaded || frame != null) return child;
        return const Center(child: CupertinoActivityIndicator());
      },
      errorBuilder: (_, _, _) => const _ImageErrorPlaceholder(),
    );
    if (fullUrl.isEmpty || fullUrl == thumbnailUrl) return thumbnail;

    return Stack(
      fit: StackFit.expand,
      children: [
        thumbnail,
        Image.network(
          fullUrl,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, synchronouslyLoaded) {
            final ready = synchronouslyLoaded || frame != null;
            return AnimatedOpacity(
              opacity: ready ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: child,
            );
          },
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceMuted(context),
      child: Center(
        child: Icon(
          CupertinoIcons.photo,
          color: AppColors.textMuted(context),
          size: 34,
        ),
      ),
    );
  }
}

class _ComposerContextPanel extends StatelessWidget {
  const _ComposerContextPanel({
    required this.title,
    required this.preview,
    required this.onCancel,
  });

  final String title;
  final String preview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(6, 2, 6, 6),
      padding: const EdgeInsets.fromLTRB(11, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(13),
        border: const Border(
          left: BorderSide(color: AppColors.purple, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.purple,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionFor(context),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.t('common.cancel'),
            onPressed: onCancel,
            visualDensity: VisualDensity.compact,
            icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ImageComposerPreview extends StatelessWidget {
  const _ImageComposerPreview({
    required this.image,
    required this.progress,
    required this.onRemove,
  });

  final _PreparedChatImage image;
  final double progress;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 7),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Image.memory(image.bytes, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('messages.photoReady'),
                  style: AppTextStyles.sectionFor(
                    context,
                  ).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(99),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.t('common.delete'),
            onPressed: onRemove,
            icon: const Icon(CupertinoIcons.xmark_circle_fill),
          ),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted(context).withValues(alpha: .88),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: Text(
            label,
            style: AppTextStyles.captionFor(
              context,
            ).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.attachment});

  final MessageAttachmentModel attachment;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  final _transformation = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    setState(() => _zoomed = !_zoomed);
    _transformation.value = _zoomed
        ? Matrix4.diagonal3Values(2.5, 2.5, 1)
        : Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final localBytes = widget.attachment.localBytes;
    final image = localBytes != null
        ? Image.memory(localBytes, fit: BoxFit.contain)
        : Image.network(
            widget.attachment.url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CupertinoActivityIndicator(color: Colors.white),
                  ),
            errorBuilder: (_, _, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: Colors.white70,
                    size: 38,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.t('messages.imageLoadError'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: .96),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _transformation,
                minScale: 1,
                maxScale: 5,
                child: Center(child: image),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: IconButton.filled(
              tooltip: context.l10n.t('common.close'),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: .48),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(CupertinoIcons.xmark),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparedChatImage {
  const _PreparedChatImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

String _imageMimeType(XFile file) {
  final direct = file.mimeType?.trim().toLowerCase();
  if (direct == 'image/png' ||
      direct == 'image/webp' ||
      direct == 'image/jpeg') {
    return direct!;
  }
  final path = file.name.toLowerCase();
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

bool _sameLocalDay(DateTime? left, DateTime? right) {
  if (left == null || right == null) return false;
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _formatMessageTime(MessageModel message) {
  final date = message.localCreatedAt;
  return date == null ? '' : DateFormat('HH:mm').format(date);
}

String _formatDayLabel(BuildContext context, DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  if (_sameLocalDay(date, now)) return context.l10n.t('messages.today');
  if (_sameLocalDay(date, now.subtract(const Duration(days: 1)))) {
    return context.l10n.t('messages.yesterday');
  }
  final locale = context.l10n.locale.languageCode;
  final pattern = date.year == now.year ? 'd MMMM' : 'd MMMM yyyy';
  final formatted = DateFormat(pattern, locale).format(date);
  return locale == 'uz' ? formatted.replaceFirst(' ', '-') : formatted;
}

String _formatConversationTime(BuildContext context, MessageModel message) {
  final date = message.localCreatedAt;
  if (date == null) return '';
  final now = DateTime.now();
  if (_sameLocalDay(date, now)) return DateFormat('HH:mm').format(date);
  if (_sameLocalDay(date, now.subtract(const Duration(days: 1)))) {
    return context.l10n.t('messages.yesterday');
  }
  return DateFormat('dd.MM.yyyy').format(date);
}

bool _conversationListsEquivalent(
  List<ConversationModel> left,
  List<ConversationModel> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    final a = left[index];
    final b = right[index];
    if (a.user.id != b.user.id ||
        a.user.isOnline != b.user.isOnline ||
        a.user.lastSeenAt != b.user.lastSeenAt ||
        a.unreadCount != b.unreadCount ||
        a.lastMessage?.syncSignature != b.lastMessage?.syncSignature) {
      return false;
    }
  }
  return true;
}

class _BattleInviteSheet extends StatefulWidget {
  const _BattleInviteSheet({
    required this.lessons,
    required this.receiver,
    required this.service,
  });

  final List<LessonModel> lessons;
  final PublicUserModel receiver;
  final BattleService service;

  @override
  State<_BattleInviteSheet> createState() => _BattleInviteSheetState();
}

class _BattleInviteSheetState extends State<_BattleInviteSheet> {
  int? _lessonId;
  int _limit = 10;
  int _duration = 90;
  String _direction = 'eng_to_uz';
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.invite(
        receiverId: widget.receiver.id,
        lessonId: _lessonId,
        limit: _limit,
        durationSeconds: _duration,
        direction: _direction,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = userFacingError(context, error));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  LessonModel? get _lesson {
    for (final lesson in widget.lessons) {
      if (lesson.id == _lessonId) return lesson;
    }
    return null;
  }

  Future<void> _pickLesson() async {
    final result = await showLessonPickerSheet(
      context: context,
      lessons: widget.lessons,
      selectedLesson: _lesson,
      allowAllWords: true,
    );
    if (result != null && mounted) {
      setState(() => _lessonId = result.lesson?.id);
    }
  }

  Future<void> _pickLimit() async {
    final value = await showIosSelectionSheet<int>(
      context: context,
      title: context.l10n.t('battle.limit'),
      selected: _limit,
      options: [
        for (final count in const [10, 20, 30])
          IosSelectionOption(
            value: count,
            label: context.l10n.f('quiz.questionCount', {'count': count}),
          ),
      ],
    );
    if (value != null && mounted) setState(() => _limit = value);
  }

  Future<void> _pickDuration() async {
    final value = await showIosSelectionSheet<int>(
      context: context,
      title: context.l10n.t('battle.duration'),
      selected: _duration,
      options: [
        for (final seconds in const [60, 90, 120])
          IosSelectionOption(
            value: seconds,
            label: context.l10n.f('common.seconds', {'seconds': seconds}),
          ),
      ],
    );
    if (value != null && mounted) setState(() => _duration = value);
  }

  Future<void> _pickDirection() async {
    final value = await showIosSelectionSheet<String>(
      context: context,
      title: context.l10n.t('quiz.direction'),
      selected: _direction,
      options: [
        IosSelectionOption(
          value: 'eng_to_uz',
          label: context.l10n.t('quiz.engToUz'),
        ),
        IosSelectionOption(
          value: 'uz_to_eng',
          label: context.l10n.t('quiz.uzToEng'),
        ),
      ],
    );
    if (value != null && mounted) setState(() => _direction = value);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: GlassCard(
          borderRadius: 26,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sports_martial_arts_rounded,
                      color: AppColors.purple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.t('battle.offer'),
                        style: AppTextStyles.titleFor(context),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(CupertinoIcons.xmark_circle_fill),
                    ),
                  ],
                ),
                Text(
                  context.l10n.f('battle.inviteUser', {
                    'name': widget.receiver.name,
                  }),
                  style: AppTextStyles.captionFor(context),
                ),
                const SizedBox(height: 16),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.divider(context)),
                  ),
                  child: Column(
                    children: [
                      IosSettingRow(
                        icon: CupertinoIcons.book_fill,
                        iconColor: AppColors.blue,
                        title: context.l10n.t('battle.lesson'),
                        value:
                            _lesson?.title ?? context.l10n.t('battle.allWords'),
                        onTap: _pickLesson,
                      ),
                      IosSettingRow(
                        icon: CupertinoIcons.number,
                        iconColor: AppColors.green,
                        title: context.l10n.t('battle.limit'),
                        value: context.l10n.f('quiz.questionCount', {
                          'count': _limit,
                        }),
                        onTap: _pickLimit,
                      ),
                      IosSettingRow(
                        icon: CupertinoIcons.timer_fill,
                        iconColor: AppColors.gold,
                        title: context.l10n.t('battle.duration'),
                        value: context.l10n.f('common.seconds', {
                          'seconds': _duration,
                        }),
                        onTap: _pickDuration,
                      ),
                      IosSettingRow(
                        icon: CupertinoIcons.arrow_left_right,
                        iconColor: AppColors.purple,
                        title: context.l10n.t('quiz.direction'),
                        value: context.l10n.t(
                          _direction == 'uz_to_eng'
                              ? 'quiz.uzToEng'
                              : 'quiz.engToUz',
                        ),
                        showDivider: false,
                        onTap: _pickDirection,
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorStateView(message: _error!),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(context.l10n.t('battle.sendInvite')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
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

class _BattleInviteCard extends StatelessWidget {
  const _BattleInviteCard({
    required this.invite,
    required this.mine,
    required this.updating,
    required this.onAction,
    required this.onOpen,
  });

  final BattleInviteModel invite;
  final bool mine;
  final bool updating;
  final ValueChanged<String> onAction;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (invite.status) {
      'accepted' => AppColors.green,
      'declined' || 'cancelled' || 'expired' => AppColors.softRed,
      _ => AppColors.gold,
    };
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .88,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            opacity: .52,
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.sports_martial_arts_rounded,
                        color: AppColors.purple,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.t('battle.chatInvite'),
                        style: AppTextStyles.sectionFor(
                          context,
                        ).copyWith(fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        context.l10n.t('battle.status.${invite.status}'),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InviteDetail(
                  icon: Icons.menu_book_rounded,
                  text: invite.lessonTitle ?? context.l10n.t('battle.allWords'),
                ),
                _InviteDetail(
                  icon: Icons.compare_arrows_rounded,
                  text: invite.direction == 'eng_to_uz' ? 'EN → UZ' : 'UZ → EN',
                ),
                _InviteDetail(
                  icon: Icons.quiz_rounded,
                  text: context.l10n.f('battle.inviteRules', {
                    'count': invite.questionLimit,
                    'seconds': invite.durationSeconds,
                  }),
                ),
                if (updating) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 3),
                ] else if (invite.canAccept) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onAction('decline'),
                          child: Text(context.l10n.t('battle.decline')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => onAction('accept'),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(context.l10n.t('battle.accept')),
                        ),
                      ),
                    ],
                  ),
                ] else if (invite.canCancel) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => onAction('cancel'),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(context.l10n.t('battle.cancelInvite')),
                  ),
                ] else if (invite.accepted) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(context.l10n.t('battle.open')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteDetail extends StatelessWidget {
  const _InviteDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textMuted(context)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.captionFor(context))),
        ],
      ),
    );
  }
}

class _BattleResultCard extends StatelessWidget {
  const _BattleResultCard({
    required this.message,
    required this.mine,
    required this.onOpen,
  });

  final MessageModel message;
  final bool mine;
  final VoidCallback onOpen;

  String _resultText(BuildContext context) {
    final explicitDraw = message.metadata['draw'];
    final winnerName = message.metadata['winner_name']?.toString().trim() ?? '';
    if (explicitDraw == true || explicitDraw?.toString() == '1') {
      return context.l10n.t('battle.draw');
    }
    if (winnerName.isNotEmpty) {
      return context.l10n.f('battle.winner', {'name': winnerName});
    }

    final scores = message.metadata['result'];
    if (scores is List && scores.isNotEmpty) {
      final first = scores.first;
      final second = scores.length > 1 ? scores[1] : null;
      if (first is Map && second is Map) {
        final draw =
            _asInt(first['correct_count']) == _asInt(second['correct_count']) &&
            _asInt(first['average_ms']) == _asInt(second['average_ms']);
        if (draw) return context.l10n.t('battle.draw');
      }
      if (first is Map && first['user'] is Map) {
        final name = (first['user'] as Map)['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          return context.l10n.f('battle.winner', {'name': name});
        }
      }
    }
    return message.body;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .84,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.gold,
                  size: 38,
                ),
                const SizedBox(height: 8),
                Text(
                  _resultText(context),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sectionFor(
                    context,
                  ).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: Text(context.l10n.t('battle.viewResult')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
