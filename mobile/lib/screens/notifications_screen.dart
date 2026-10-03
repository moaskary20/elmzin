import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../data/notifications_store.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.onBack,
    this.onOpenBookings,
  });

  final VoidCallback onBack;
  final VoidCallback? onOpenBookings;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    NotificationsStore.instance.attach();
    NotificationsStore.instance.refresh(
      quiet: NotificationsStore.instance.loaded,
    );
  }

  void _open(AppNotice notice) {
    NotificationsStore.instance.markRead(notice);
    if (notice.bookingId != null && widget.onOpenBookings != null) {
      widget.onOpenBookings!();
    }
  }

  void _login() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final english = Directionality.of(context) == TextDirection.ltr;
    final store = NotificationsStore.instance;

    return ColoredBox(
      key: const Key('notifications-screen'),
      color: AppColors.black,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([AccountStore.instance, store]),
          builder: (context, _) {
            final account = AccountStore.instance;
            final canMark =
                account.loggedIn && account.notifications && store.unread > 0;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('notifications-back'),
                        onPressed: widget.onBack,
                        icon: Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.arrow_forward_rounded
                              : Icons.arrow_back_rounded,
                          color: AppColors.gold,
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              english ? 'Notifications' : 'الإشعارات',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (canMark) ...[
                              const SizedBox(width: 8),
                              Container(
                                key: const Key('notifications-unread'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${store.unread}',
                                  style: TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canMark)
                        TextButton(
                          key: const Key('notifications-read-all'),
                          onPressed: store.markAllRead,
                          child: Text(
                            english ? 'Mark all read' : 'تحديد الكل كمقروء',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: _body(english, store)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(bool english, NotificationsStore store) {
    final account = AccountStore.instance;
    if (!account.loggedIn) {
      return _Muted(
        key: const Key('notifications-guest'),
        icon: Icons.lock_outline_rounded,
        title: english
            ? 'Sign in to see notices'
            : 'سجّل الدخول لمتابعة إشعاراتك',
        body: english
            ? 'Booking updates, offers and points appear here.'
            : 'تحديثات الحجوزات والنقاط والمحفظة تظهر هنا فور حدوثها.',
        action: english ? 'Sign in' : 'تسجيل الدخول',
        onAction: _login,
      );
    }
    if (!account.notifications) {
      return _Muted(
        icon: Icons.notifications_off_outlined,
        title: english ? 'Notifications are off' : 'الإشعارات متوقفة',
        body: english
            ? 'Turn them on from Settings to see new notices.'
            : 'فعّلها من الإعدادات لتظهر التنبيهات الجديدة.',
      );
    }
    if (!store.loaded && store.loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (!store.loaded && store.failed) {
      return _Muted(
        icon: Icons.wifi_off_rounded,
        title: english ? 'Could not load' : 'تعذر تحميل الإشعارات',
        body: english
            ? 'Check your connection and try again.'
            : 'تحقق من الاتصال ثم أعد المحاولة.',
        action: english ? 'Retry' : 'إعادة المحاولة',
        onAction: store.refresh,
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.panel,
      onRefresh: () => store.refresh(quiet: true),
      child: store.items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 420,
                  child: _Muted(
                    key: const Key('notifications-empty'),
                    icon: Icons.notifications_none_rounded,
                    title: english ? 'No notices yet' : 'لا توجد إشعارات بعد',
                    body: english
                        ? 'Every booking update will show up here.'
                        : 'كل حركة على حجوزاتك ومحفظتك ونقاطك ستظهر هنا.',
                  ),
                ),
              ],
            )
          : ListView.separated(
              key: const Key('notifications-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: store.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = store.items[index];
                return _NoticeCard(
                  key: Key('notice-${item.id}'),
                  item: item,
                  english: english,
                  onTap: () => _open(item),
                );
              },
            ),
    );
  }
}

IconData _iconFor(String type) {
  switch (type) {
    case 'booking_created':
    case 'booking_new':
      return Icons.event_note_rounded;
    case 'booking_confirmed':
      return Icons.event_available_rounded;
    case 'booking_cancelled':
      return Icons.event_busy_rounded;
    case 'booking_completed':
      return Icons.task_alt_rounded;
    case 'booking_rescheduled':
      return Icons.update_rounded;
    case 'booking_pending':
      return Icons.hourglass_top_rounded;
    case 'review_new':
      return Icons.star_rounded;
    case 'salon_verified':
      return Icons.verified_rounded;
    case 'salon_rejected':
      return Icons.gpp_bad_outlined;
    case 'salon_pending':
      return Icons.pending_outlined;
    case 'wallet':
      return Icons.account_balance_wallet_outlined;
    case 'loyalty':
      return Icons.workspace_premium_outlined;
    case 'security':
      return Icons.lock_reset_rounded;
    case 'welcome':
      return Icons.waving_hand_outlined;
  }
  return Icons.notifications_none_rounded;
}

String _when(DateTime? at, bool english) {
  if (at == null) return '';
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return english ? 'now' : 'الآن';
  if (diff.inMinutes < 60) {
    return english ? '${diff.inMinutes}m' : 'منذ ${diff.inMinutes} د';
  }
  if (diff.inHours < 24) {
    return english ? '${diff.inHours}h' : 'منذ ${diff.inHours} س';
  }
  if (diff.inDays == 1) return english ? 'Yesterday' : 'أمس';
  if (diff.inDays < 7) {
    return english ? '${diff.inDays}d' : 'منذ ${diff.inDays} أيام';
  }
  final month = at.month.toString().padLeft(2, '0');
  final day = at.day.toString().padLeft(2, '0');
  return '${at.year}/$month/$day';
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    super.key,
    required this.item,
    required this.english,
    required this.onTap,
  });

  final AppNotice item;
  final bool english;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fresh = !item.read;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          decoration: BoxDecoration(
            color: fresh
                ? Color.alphaBlend(
                    AppColors.gold.withValues(alpha: 0.08),
                    AppColors.panel,
                  )
                : AppColors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: fresh
                  ? AppColors.gold.withValues(alpha: 0.55)
                  : AppColors.line,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: fresh ? 0.22 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconFor(item.type),
                  color: AppColors.gold,
                  size: 22,
                ),
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
                            item.title,
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 15,
                              fontWeight: fresh
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _when(item.createdAt, english),
                          style: TextStyle(
                            color: AppColors.goldSoft,
                            fontSize: 12,
                          ),
                        ),
                        if (fresh) ...[
                          const SizedBox(width: 6),
                          Container(
                            key: Key('notice-dot-${item.id}'),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        color: AppColors.goldSoft,
                        fontSize: 13,
                        height: 1.45,
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

class _Muted extends StatelessWidget {
  const _Muted({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.gold, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.goldSoft,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('notifications-action'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 12,
                ),
              ),
              onPressed: onAction,
              child: Text(
                action!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
