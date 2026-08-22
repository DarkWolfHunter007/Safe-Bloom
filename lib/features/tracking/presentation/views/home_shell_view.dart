import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../insights/presentation/views/insights_view.dart';
import '../../../settings/presentation/views/settings_view.dart';
import 'calendar_view.dart';
import 'today_view.dart';

class HomeShellView extends StatefulWidget {
  const HomeShellView({super.key});

  @override
  State<HomeShellView> createState() => _HomeShellViewState();
}

class _HomeShellViewState extends State<HomeShellView> {
  int _currentIndex = 0;
  final GlobalKey<TodayViewState> _todayKey = GlobalKey<TodayViewState>();
  final GlobalKey<CalendarViewState> _calendarKey = GlobalKey<CalendarViewState>();
  final GlobalKey<InsightsViewState> _insightsKey = GlobalKey<InsightsViewState>();
  final GlobalKey<SettingsViewState> _settingsKey = GlobalKey<SettingsViewState>();

  late final List<Widget> _views;

  @override
  void initState() {
    super.initState();
    _views = [
      TodayView(key: _todayKey),
      CalendarView(key: _calendarKey),
      InsightsView(key: _insightsKey),
      SettingsView(key: _settingsKey),
    ];
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    if (index == 0) _todayKey.currentState?.refresh();
    if (index == 1) _calendarKey.currentState?.refresh();
    if (index == 2) _insightsKey.currentState?.refresh();
    if (index == 3) _settingsKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _views,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: AppColors.lightCardBackground,
        selectedItemColor: AppColors.dropCoral,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 9),
        unselectedLabelStyle: AppTypography.brandTagline(color: AppColors.textMuted, fontSize: 9),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.today_outlined),
            activeIcon: Icon(Icons.today),
            label: 'TODAY',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'CALENDAR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'INSIGHTS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'PROFILE',
          ),
        ],
      ),
    );
  }
}
