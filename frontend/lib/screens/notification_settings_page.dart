import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/notification_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/app_background.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  static const List<String> _defaultReminderTimes = ['08:00', '12:30', '18:30'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadPreferences();
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  TimeOfDay _parseReminderTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return const TimeOfDay(hour: 8, minute: 0);
    }

    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatReminderTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _editReminderTimes(
    NotificationProvider provider,
    LanguageProvider lang,
  ) async {
    final currentTimes = List<String>.from(
      provider.preferences?.reminderTimes ?? _defaultReminderTimes,
    );
    while (currentTimes.length < 3) {
      currentTimes.add(_defaultReminderTimes[currentTimes.length]);
    }

    final labels = [lang.t('breakfast'), lang.t('lunch'), lang.t('dinner')];
    final updatedTimes = List<String>.from(currentTimes.take(3));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickTime(int index) async {
              final selected = await showTimePicker(
                context: context,
                initialTime: _parseReminderTime(updatedTimes[index]),
              );
              if (selected == null) return;

              setModalState(() {
                updatedTimes[index] = _formatReminderTime(selected);
              });
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    lang.t('reminder_times'),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(3, (index) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        labels[index],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        updatedTimes[index],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.schedule,
                        color: AppColors.primaryGreen,
                      ),
                      onTap: () => pickTime(index),
                    );
                  }),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(bottomSheetContext),
                        child: Text(lang.t('cancel')),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(bottomSheetContext);
                          await provider.updatePreferences(
                            reminderTimes: updatedTimes,
                          );
                          if (!mounted) return;
                          navigator.pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(lang.t('save')),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(lang),
              Expanded(
                child: Consumer<NotificationProvider>(
                  builder: (context, provider, _) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildPreferencesCard(provider, lang),
                          const SizedBox(height: 24),
                          _buildNotificationsList(provider, lang),
                          const SizedBox(height: 32),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            lang.t('notifications'),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(
      NotificationProvider provider, LanguageProvider lang) {
    final prefs = provider.preferences;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('notification_preferences'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(
              lang.t('meal_reminders'),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            subtitle: Text(
              lang.t('meal_reminders_desc'),
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            value: prefs?.mealReminders ?? true,
            activeColor: AppColors.primaryGreen,
            onChanged: (value) {
              provider.updatePreferences(mealReminders: value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text(
              lang.t('health_alerts'),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            subtitle: Text(
              lang.t('health_alerts_desc'),
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            value: prefs?.healthAlerts ?? true,
            activeColor: AppColors.primaryGreen,
            onChanged: (value) {
              provider.updatePreferences(healthAlerts: value);
            },
          ),
          const Divider(),
          ListTile(
            title: Text(
              lang.t('reminder_times'),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            subtitle: Text(
              prefs?.reminderTimes.join(', ') ?? '08:00, 12:30, 18:30',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.schedule, color: AppColors.primaryGreen),
            onTap: () => _editReminderTimes(provider, lang),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
      NotificationProvider provider, LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              lang.t('recent_notifications'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (provider.notifications.any((n) => !n.isRead))
              TextButton(
                onPressed: () => provider.markAllAsRead(),
                child: Text(
                  lang.t('mark_all_read'),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (provider.isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          )
        else if (provider.notifications.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.notifications_off_outlined,
                    size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(
                  lang.t('no_notifications'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...provider.notifications.map(
            (notification) => _buildNotificationTile(notification, provider),
          ),
      ],
    );
  }

  Widget _buildNotificationTile(
      dynamic notification, NotificationProvider provider) {
    final isHealthAlert = notification.type == 'health_alert';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: notification.isRead
            ? AppColors.cardFill
            : AppColors.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: notification.isRead
            ? null
            : Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isHealthAlert
                ? AppColors.error.withOpacity(0.1)
                : AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            isHealthAlert ? Icons.warning_amber : Icons.restaurant,
            color: isHealthAlert ? AppColors.error : AppColors.primaryGreen,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          notification.body,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          if (!notification.isRead) {
            provider.markAsRead(notification.id);
          }
        },
      ),
    );
  }
}
