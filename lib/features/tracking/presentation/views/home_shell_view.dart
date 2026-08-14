import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../insights/presentation/views/insights_view.dart';
import '../../../insights/presentation/widgets/cycle_charts_widget.dart';
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
  final GlobalKey<CycleChartsWidgetState> _chartsKey = GlobalKey<CycleChartsWidgetState>();
  final GlobalKey<SettingsViewState> _settingsKey = GlobalKey<SettingsViewState>();

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);

    if (index == 0) {
      _todayKey.currentState?.refresh();
    } else if (index == 1) {
      _calendarKey.currentState?.refresh();
    } else if (index == 2) {
      _chartsKey.currentState?.refresh();
    } else if (index == 3) {
      _settingsKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            TodayView(key: _todayKey),
            CalendarView(key: _calendarKey),
            InsightsView(chartsKey: _chartsKey),
            SettingsView(key: _settingsKey),
          ],
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
