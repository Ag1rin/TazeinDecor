// Home Screen with Role-Based Navigation
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/websocket_service.dart';
import 'products/products_home.dart';
import 'invoices/invoices_screen.dart';
import 'chat/chat_room_screen.dart';
import 'reports/reports_screen.dart';
import 'users/users_management_screen.dart';
import 'companies/companies_screen.dart';
import 'profile/profile_screen.dart';
import 'operator/operator_dashboard.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _unreadCount = 0;
  bool _badgePulse = false;
  WebSocketService? _wsService;
  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<ChatMessage>? _updateSub;
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _startBadgePulse();
    _initWebSocket();
  }

  void _startBadgePulse() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (_unreadCount > 0) {
        setState(() {
          _badgePulse = !_badgePulse;
        });
      }
    });
  }

  Future<void> _initWebSocket() async {
    try {
      _wsService = WebSocketService();
      await _wsService!.connect();

      _messageSub = _wsService!.messageStream.listen((_) {
        if (!_isOnChatTab()) {
          setState(() {
            _unreadCount = (_unreadCount + 1).clamp(0, 999);
          });
        }
      });

      _updateSub = _wsService!.updateStream.listen((_) {});
    } catch (e) {
      debugPrint('Home WebSocket init failed: $e');
    }
  }

  bool _isOnChatTab() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return false;
    return _currentIndex == _chatTabIndex(auth.user!);
  }

  int _chatTabIndex(UserModel user) {
    if (user.isAdmin) return 2;
    if (user.isOperator) return 3;
    if (user.isStoreManager) return 4;
    return 2; // seller
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _messageSub?.cancel();
    _updateSub?.cancel();
    _wsService?.dispose();
    super.dispose();
  }

  List<Widget> _getPagesForRole(UserModel user) {
    if (user.isAdmin) {
      return [
        const ReportsScreen(),
        const UsersManagementScreen(),
        const ChatRoomScreen(),
        const ProfileScreen(),
      ];
    } else if (user.isOperator) {
      return [
        const OperatorDashboard(),
        const InvoicesScreen(),
        const CompaniesScreen(),
        const ChatRoomScreen(),
        const ProfileScreen(),
      ];
    } else if (user.isStoreManager) {
      return [
        const ProductsHome(),
        const InvoicesScreen(),
        const ReportsScreen(),
        const UsersManagementScreen(),
        const ChatRoomScreen(),
        const ProfileScreen(),
      ];
    } else {
      // Seller
      return [
        const ProductsHome(),
        const InvoicesScreen(),
        const ChatRoomScreen(),
        const ProfileScreen(),
      ];
    }
  }

  List<BottomNavigationBarItem> _getNavItemsForRole(UserModel user) {
    Widget chatIcon() {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.chat),
          if (_unreadCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _badgePulse ? 0.5 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _unreadCount > 10 ? '+10' : '$_unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (user.isAdmin) {
      return [
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'گزارش‌ها',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'کاربران',
        ),
        BottomNavigationBarItem(icon: chatIcon(), label: 'چت'),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'پروفایل',
        ),
      ];
    } else if (user.isOperator) {
      return [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'داشبورد',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'فاکتورها',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.business),
          label: 'شرکت‌ها',
        ),
        BottomNavigationBarItem(icon: chatIcon(), label: 'چت'),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'پروفایل',
        ),
      ];
    } else if (user.isStoreManager) {
      return [
        const BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag),
          label: 'محصولات',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'فاکتورها',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'گزارش‌ها',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'فروشندگان',
        ),
        BottomNavigationBarItem(icon: chatIcon(), label: 'چت'),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'پروفایل',
        ),
      ];
    } else {
      // Seller
      return [
        const BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag),
          label: 'محصولات',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'فاکتورها',
        ),
        BottomNavigationBarItem(icon: chatIcon(), label: 'چت'),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'پروفایل',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pages = _getPagesForRole(authProvider.user!);
        final navItems = _getNavItemsForRole(authProvider.user!);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: IndexedStack(index: _currentIndex, children: pages),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                  if (_isOnChatTab()) {
                    _unreadCount = 0;
                  }
                });
              },
              type: BottomNavigationBarType.fixed,
              items: navItems,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
            ),
          ),
        );
      },
    );
  }
}
