import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'dart:ui'; // For BackdropFilter

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _reminderMinutes = 15;
  String _selectedAudio = 'Default (Chime)';
  bool _pushEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _reminderMinutes = prefs.getInt('reminderMinutes') ?? 15;
      _selectedAudio = prefs.getString('selectedAudio') ?? 'Default (Chime)';
      _pushEnabled = prefs.getBool('pushEnabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // Uses background of main layout
      body: Column(
        children: [
          // Header
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.panelDark.withOpacity(0.8)
                      : Colors.white.withOpacity(0.8),
                  border: Border(
                      bottom: BorderSide(
                          color: isDark
                              ? AppTheme.primaryColor.withOpacity(0.1)
                              : Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('NOTIFICATIONS & ALERTS'),
                    const SizedBox(height: 16),
                    _buildSettingsCard(
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          isDark: isDark,
                          icon: Icons.notifications_active,
                          title: 'Enable Push Notifications',
                          subtitle: 'Receive alerts when changes are detected',
                          trailing: Switch(
                            value: _pushEnabled,
                            onChanged: (val) {
                              setState(() => _pushEnabled = val);
                              _saveSetting('pushEnabled', val);
                            },
                            activeColor: AppTheme.primaryColor,
                          ),
                        ),
                        _buildDivider(isDark),
                        _buildSettingsRow(
                          isDark: isDark,
                          icon: Icons.timer,
                          title: 'Reminder Interval',
                          subtitle: 'If unread, notify me again every...',
                          trailing: DropdownButton<int>(
                            value: _reminderMinutes,
                            underline: const SizedBox(),
                            dropdownColor:
                                isDark ? AppTheme.panelDark : Colors.white,
                            items: const [
                              DropdownMenuItem(value: 5, child: Text('5 mins')),
                              DropdownMenuItem(
                                  value: 15, child: Text('15 mins')),
                              DropdownMenuItem(
                                  value: 30, child: Text('30 mins')),
                              DropdownMenuItem(
                                  value: 60, child: Text('1 hour')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _reminderMinutes = val);
                                _saveSetting('reminderMinutes', val);
                              }
                            },
                          ),
                        ),
                        _buildDivider(isDark),
                        _buildSettingsRow(
                          isDark: isDark,
                          icon: Icons.music_note,
                          title: 'Notification Audio',
                          subtitle: 'Sound played on alert',
                          trailing: DropdownButton<String>(
                            value: _selectedAudio,
                            underline: const SizedBox(),
                            dropdownColor:
                                isDark ? AppTheme.panelDark : Colors.white,
                            items: const [
                              DropdownMenuItem(
                                  value: 'Default (Chime)',
                                  child: Text('Chime')),
                              DropdownMenuItem(
                                  value: 'Bell', child: Text('Bell')),
                              DropdownMenuItem(
                                  value: 'Radar', child: Text('Radar')),
                              DropdownMenuItem(
                                  value: 'Mute', child: Text('Mute')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedAudio = val);
                                _saveSetting('selectedAudio', val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('APPEARANCE'),
                    const SizedBox(height: 16),
                    _buildSettingsCard(
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          isDark: isDark,
                          icon: Icons.dark_mode,
                          title: 'Theme',
                          subtitle:
                              'Automatically matches your system preferences.',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Auto (System)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('ABOUT'),
                    const SizedBox(height: 16),
                    _buildSettingsCard(
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          isDark: isDark,
                          icon: Icons.info_outline,
                          title: 'Version',
                          subtitle: 'NotifyMe v1.0.0 (Beta)',
                          trailing: const SizedBox(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: const Color(0xFF0A0F0D),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          // Already saved via onChanged, but provide feedback
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Settings saved successfully!')),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save Settings',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSettingsCard(
      {required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsRow({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 20,
                color: isDark ? Colors.white70 : Colors.grey.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
      indent: 64,
    );
  }
}
