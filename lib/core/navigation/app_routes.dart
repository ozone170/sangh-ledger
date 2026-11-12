import 'package:flutter/material.dart';
import '../../features/authentication/login_screen.dart';
import '../../features/loans/loan_detail_screen.dart';
import '../../features/members/member_detail_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/repayments/repayment_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import 'main_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String mainShell = '/main';
  static const String memberDetail = '/member-detail';
  static const String loanDetail = '/loan-detail';
  static const String repayment = '/repayment';
  static const String transactions = '/transactions';
  static const String reports = '/reports';
  static const String settings = '/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settingsArgs) {
    switch (settingsArgs.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case mainShell:
        final tabIndex = settingsArgs.arguments as int? ?? 0;
        return MaterialPageRoute(builder: (_) => MainShell(initialIndex: tabIndex));
      case memberDetail:
        final memberId = settingsArgs.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: memberId));
      case loanDetail:
        final loanId = settingsArgs.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loanId));
      case repayment:
        final loanId = settingsArgs.arguments as String?;
        return MaterialPageRoute(builder: (_) => RepaymentScreen(loanId: loanId));
      case transactions:
        return MaterialPageRoute(builder: (_) => const TransactionsScreen());
      case reports:
        return MaterialPageRoute(builder: (_) => const ReportsScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settingsArgs.name}')),
          ),
        );
    }
  }
}
