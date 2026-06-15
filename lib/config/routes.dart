import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/add_expense_screen.dart';
import '../screens/expense_detail_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/invite_assistant_screen.dart';
import '../models/expense.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String addExpense = '/add-expense';
  static const String expenseDetail = '/expense-detail';
  static const String reports = '/reports';
  static const String inviteAssistant = '/invite-assistant';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case addExpense:
        final args = settings.arguments as AddExpenseScreenArgs?;
        return MaterialPageRoute(
          builder: (_) => AddExpenseScreen(args: args),
        );
      case expenseDetail:
        final expense = settings.arguments as Expense;
        return MaterialPageRoute(
          builder: (_) => ExpenseDetailScreen(expense: expense),
        );
      case reports:
        return MaterialPageRoute(builder: (_) => const ReportsScreen());
      case inviteAssistant:
        return MaterialPageRoute(builder: (_) => const InviteAssistantScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
