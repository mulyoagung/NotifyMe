import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/dashboard_screen.dart';
import 'screens/vercel_dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await NotificationService.instance.init();
    await BackgroundService.init();
  }
  runApp(const NotifyMeApp());
}

class NotifyMeApp extends StatelessWidget {
  const NotifyMeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NotifyMe',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainNavigation(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const VercelDashboardScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width >= 1024;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Left Sidebar
            Container(
              width: 256, // 64 spacing (tailwind w-64)
              decoration: BoxDecoration(
                color:
                    isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
                border: Border(
                    right: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  // Logo Area
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Icon(Icons.monitor_heart,
                            color: AppTheme.primaryColor, size: 32),
                        const SizedBox(width: 12),
                        Text(
                          'NotifyMe',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Navigation Links
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _buildSidebarItem(0, 'Home', Icons.dashboard_outlined,
                            Icons.dashboard),
                        _buildSidebarItem(1, 'Dashboard', Icons.layers_outlined,
                            Icons.layers),
                        _buildSidebarItem(2, 'Settings',
                            Icons.settings_outlined, Icons.settings),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: Container(
                color:
                    isDark ? const Color(0xFF0D1310) : AppTheme.backgroundLight,
                child: _pages[_currentIndex],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile/Tablet Fallback
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.layers_outlined),
            activeIcon: Icon(Icons.layers),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
      int index, String title, IconData icon, IconData activeIcon) {
    bool isSelected = _currentIndex == index;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? const Border(
                  right: BorderSide(color: AppTheme.primaryColor, width: 3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
