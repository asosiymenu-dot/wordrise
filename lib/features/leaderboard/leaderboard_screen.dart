import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/leaderboard_user_tile.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/api_models.dart';
import '../../services/battle_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/lesson_service.dart';
import '../../services/message_service.dart';
import '../../services/presence_service.dart';
import '../../services/websocket_service.dart';
import '../messages/messages_screen.dart';
import '../profile/public_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    required this.service,
    required this.messageService,
    required this.currentUser,
    required this.battleService,
    required this.lessonService,
    required this.presenceService,
    required this.websocketService,
    super.key,
  });

  final LeaderboardService service;
  final MessageService messageService;
  final UserModel currentUser;
  final BattleService battleService;
  final LessonService lessonService;
  final PresenceService presenceService;
  final WebSocketService websocketService;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _scope = 'global';
  bool _friendsOnly = false;
  late Future<List<LeaderboardUserModel>> _future;

  @override
  void initState() {
    super.initState();
    _load('global');
  }

  void _load(String scope, {bool? friendsOnly}) {
    setState(() {
      _scope = scope;
      _friendsOnly = friendsOnly ?? _friendsOnly;
      _future = _friendsOnly
          ? widget.service.friends(scope: scope)
          : switch (scope) {
              'daily' => widget.service.daily(),
              'weekly' => widget.service.weekly(),
              _ => widget.service.global(),
            };
    });
  }

  Future<void> _openChat(LeaderboardUserModel user) async {
    if (user.id == widget.currentUser.id) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatThreadScreen(
          currentUser: widget.currentUser,
          otherUser: user.toPublicUser(),
          service: widget.messageService,
          battleService: widget.battleService,
          lessonService: widget.lessonService,
          presenceService: widget.presenceService,
          websocketService: widget.websocketService,
        ),
      ),
    );
  }

  Future<void> _openProfile(LeaderboardUserModel user) async {
    final publicUser = user.toPublicUser();
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (routeContext) => PublicProfileScreen(
          user: publicUser,
          onMessage: user.id == widget.currentUser.id
              ? null
              : () {
                  Navigator.of(routeContext).push(
                    CupertinoPageRoute(
                      builder: (_) => ChatThreadScreen(
                        currentUser: widget.currentUser,
                        otherUser: publicUser,
                        service: widget.messageService,
                        battleService: widget.battleService,
                        lessonService: widget.lessonService,
                        presenceService: widget.presenceService,
                        websocketService: widget.websocketService,
                      ),
                    ),
                  );
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: FutureBuilder<List<LeaderboardUserModel>>(
            future: _future,
            builder: (context, snapshot) {
              final users = snapshot.data ?? [];
              final top3 = users.take(3).toList();
              final remaining = users.length > 3 ? users.sublist(3) : <LeaderboardUserModel>[];

              LeaderboardUserModel? currentUserRank;
              for (final u in users) {
                if (u.id == widget.currentUser.id) {
                  currentUserRank = u;
                  break;
                }
              }

              return Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async => _load(_scope),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.t('leaderboard.title'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Eng faol o‘quvchilar va eng ko‘p XP to‘plaganlar',
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Scope Selector (Pill tabs)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black12,
                            ),
                          ),
                          child: Row(
                            children: [
                              _ScopeTab(
                                label: 'Barchasi',
                                icon: Icons.public_rounded,
                                active: !_friendsOnly && _scope == 'global',
                                onTap: () => _load('global', friendsOnly: false),
                              ),
                              _ScopeTab(
                                label: 'Haftalik',
                                icon: Icons.calendar_view_week_rounded,
                                active: !_friendsOnly && _scope == 'weekly',
                                onTap: () => _load('weekly', friendsOnly: false),
                              ),
                              _ScopeTab(
                                label: 'Kunlik',
                                icon: Icons.today_rounded,
                                active: !_friendsOnly && _scope == 'daily',
                                onTap: () => _load('daily', friendsOnly: false),
                              ),
                              _ScopeTab(
                                label: 'Do‘stlar',
                                icon: Icons.people_alt_rounded,
                                active: _friendsOnly,
                                onTap: () => _load(_scope, friendsOnly: !_friendsOnly),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: LoadingStateView(),
                          )
                        else if (snapshot.hasError)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: ErrorStateView(
                              message: l10n.t('common.networkError'),
                              onRetry: () => _load(_scope),
                            ),
                          )
                        else if (users.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: EmptyStateView(
                              icon: Icons.emoji_events_outlined,
                              message: _friendsOnly
                                  ? 'Hozircha do‘stlaringiz orasida reyting mavjud emas.'
                                  : 'Ushbu davrda reyting ma‘lumotlari topilmadi.',
                            ),
                          )
                        else ...[
                          // Top 3 Podium
                          if (top3.isNotEmpty)
                            _LeaderboardPodium(
                              top3: top3,
                              onOpenProfile: _openProfile,
                              onOpenChat: _openChat,
                              currentUserId: widget.currentUser.id,
                            ),
                          const SizedBox(height: 16),

                          // Remaining List (#4, #5, ...)
                          if (remaining.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: Text(
                                'BOSHQA O‘QUVCHILAR (#4 - #${users.length})',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final user in remaining) ...[
                              LeaderboardUserTile(
                                user: user,
                                isCurrentUser: user.id == widget.currentUser.id,
                                onTap: () => _openProfile(user),
                                onMessage: user.id == widget.currentUser.id
                                    ? null
                                    : () => _openChat(user),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),

                  // Sticky User Rank at the bottom
                  if (currentUserRank != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#${currentUserRank.rank}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            UserAvatar(
                              name: currentUserRank.name,
                              avatarUrl: currentUserRank.avatar,
                              size: 38,
                              online: true,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Sizning o‘rningiz (${currentUserRank.name})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'LVL ${currentUserRank.level} • ',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const Icon(Icons.local_fire_department_rounded, color: Colors.amber, size: 13),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${currentUserRank.streak} kun streak',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade400,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${currentUserRank.xp} XP',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontSize: 12,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
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

class _LeaderboardPodium extends StatelessWidget {
  const _LeaderboardPodium({
    required this.top3,
    required this.onOpenProfile,
    required this.onOpenChat,
    required this.currentUserId,
  });

  final List<LeaderboardUserModel> top3;
  final ValueChanged<LeaderboardUserModel> onOpenProfile;
  final ValueChanged<LeaderboardUserModel> onOpenChat;
  final int currentUserId;

  @override
  Widget build(BuildContext context) {
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.isDark(context)
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.isDark(context)
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 2nd Place (Silver)
          if (second != null)
            Expanded(
              child: _PodiumColumn(
                user: second,
                rank: 2,
                podiumHeight: 100,
                crownColor: const Color(0xFFC0C0C0),
                podiumColor: const Color(0xFF94A3B8),
                onTap: () => onOpenProfile(second),
              ),
            )
          else
            const Expanded(child: SizedBox()),

          // 1st Place (Gold)
          if (first != null)
            Expanded(
              child: _PodiumColumn(
                user: first,
                rank: 1,
                podiumHeight: 125,
                crownColor: const Color(0xFFFFD700),
                podiumColor: const Color(0xFFF59E0B),
                isFirst: true,
                onTap: () => onOpenProfile(first),
              ),
            )
          else
            const Expanded(child: SizedBox()),

          // 3rd Place (Bronze)
          if (third != null)
            Expanded(
              child: _PodiumColumn(
                user: third,
                rank: 3,
                podiumHeight: 85,
                crownColor: const Color(0xFFCD7F32),
                podiumColor: const Color(0xFFB45309),
                onTap: () => onOpenProfile(third),
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.user,
    required this.rank,
    required this.podiumHeight,
    required this.crownColor,
    required this.podiumColor,
    this.isFirst = false,
    required this.onTap,
  });

  final LeaderboardUserModel user;
  final int rank;
  final double podiumHeight;
  final Color crownColor;
  final Color podiumColor;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarSize = isFirst ? 68.0 : 54.0;
    final isDark = AppColors.isDark(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown / Medal Icon
          if (isFirst)
            Icon(Icons.workspace_premium_rounded, color: crownColor, size: 28)
          else if (rank == 2)
            Icon(Icons.military_tech_rounded, color: crownColor, size: 24)
          else
            Icon(Icons.military_tech_outlined, color: crownColor, size: 24),
          const SizedBox(height: 4),

          // Avatar with glowing ring
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [crownColor, crownColor.withValues(alpha: 0.4)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: crownColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: UserAvatar(
                  name: user.name,
                  avatarUrl: user.avatar,
                  size: avatarSize,
                  online: user.isOnline,
                ),
              ),
              Positioned(
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: crownColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // User Name
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: isFirst ? 13 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),

          // XP Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: crownColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${user.xp} XP',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Pedestal
          Container(
            width: double.infinity,
            height: podiumHeight,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  podiumColor.withValues(alpha: isDark ? 0.35 : 0.25),
                  podiumColor.withValues(alpha: isDark ? 0.15 : 0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(
                color: crownColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#$rank',
                  style: TextStyle(
                    color: crownColor,
                    fontSize: isFirst ? 26 : 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'LVL ${user.level}',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
