// Reports Screen with Calendar and Sales Reports
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../services/report_service.dart';
import '../../services/installation_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/persian_number.dart';
import '../../utils/persian_date.dart';
import '../../utils/jalali_date.dart';
import '../../widgets/jalali_calendar.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final ReportService _reportService = ReportService();
  final InstallationService _installationService = InstallationService();
  late TabController _tabController;

  JalaliDate _focusedDay = JalaliDate.now();
  JalaliDate _selectedDay = JalaliDate.now();
  String _selectedPeriod = 'day';

  Map<JalaliDate, List<InstallationModel>> _installations = {};
  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _sellerPerformance = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _loadInstallations(),
      _loadSalesReport(),
      _loadSellerPerformance(),
    ]);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadInstallations() async {
    final startDate = DateTime.now().subtract(const Duration(days: 60));
    final endDate = DateTime.now().add(const Duration(days: 60));

    final installations = await _installationService.getInstallations(
      startDate: startDate,
      endDate: endDate,
    );

    final Map<JalaliDate, List<InstallationModel>> grouped = {};
    for (var inst in installations) {
      final jalaliDate = JalaliDate.fromDateTime(inst.installationDate);
      // Normalize to just the date (no time)
      final dateKey = JalaliDate(jalaliDate.year, jalaliDate.month, jalaliDate.day);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(inst);
    }

    setState(() {
      _installations = grouped;
    });
  }

  Future<void> _loadSalesReport() async {
    final startDate = _getStartDateForPeriod();
    final data = await _reportService.getSalesReport(
      startDate: startDate,
      endDate: DateTime.now(),
      period: _selectedPeriod,
    );

    setState(() {
      _salesData = List<Map<String, dynamic>>.from(data['data'] ?? []);
    });
  }

  Future<void> _loadSellerPerformance() async {
    final data = await _reportService.getSellerPerformance();
    setState(() {
      _sellerPerformance = List<Map<String, dynamic>>.from(
        data['sellers'] ?? [],
      );
    });
  }

  DateTime? _getStartDateForPeriod() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'day':
        return now.subtract(const Duration(days: 30));
      case 'month':
        return DateTime(now.year - 1, now.month, 1);
      case 'year':
        return DateTime(now.year - 3, 1, 1);
      default:
        return null;
    }
  }

  List<InstallationModel> _getInstallationsForDay(JalaliDate day) {
    final dateKey = JalaliDate(day.year, day.month, day.day);
    return _installations[dateKey] ?? [];
  }

  Color _getInstallationColor(InstallationModel inst) {
    if (inst.color != null) {
      try {
        return Color(int.parse(inst.color!.replaceFirst('#', '0xFF')));
      } catch (e) {
        return AppColors.primaryBlue;
      }
    }
    return AppColors.primaryBlue;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('گزارش‌ها'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'تقویم نصب'),
              Tab(text: 'گزارش فروش'),
              Tab(text: 'عملکرد فروشندگان'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: SpinKitFadingCircle(color: AppColors.primaryBlue),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildInstallationCalendar(),
                  _buildSalesReport(),
                  _buildSellerPerformance(),
                ],
              ),
      ),
    );
  }

  Widget _buildInstallationCalendar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: JalaliCalendar<InstallationModel>(
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            firstDay: JalaliDate(1400, 1, 1),
            lastDay: JalaliDate(1410, 12, 29),
            onDaySelected: (selectedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = JalaliDate(selectedDay.year, selectedDay.month, 1);
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getInstallationsForDay,
            eventColorBuilder: (inst) => _getInstallationColor(inst),
            helpText: 'تقویم نصب',
          ),
        ),
        const Divider(),
        Expanded(child: _buildInstallationList()),
      ],
    );
  }

  Widget _buildInstallationList() {
    final installations = _getInstallationsForDay(_selectedDay);

    if (installations.isEmpty) {
      return const Center(child: Text('نصبی برای این تاریخ ثبت نشده است'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: installations.length,
      itemBuilder: (context, index) {
        final inst = installations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _getInstallationColor(inst),
                shape: BoxShape.circle,
              ),
            ),
            title: Text('نصب شماره ${inst.orderId}'),
            subtitle: Text(PersianDate.formatDate(inst.installationDate)),
            trailing: inst.notes != null ? const Icon(Icons.note) : null,
            onTap: () {
              if (inst.notes != null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('یادداشت'),
                    content: Text(inst.notes!),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('بستن'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildSalesReport() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('دوره:'),
              const SizedBox(width: 16),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'day', label: Text('روزانه')),
                    ButtonSegment(value: 'month', label: Text('ماهانه')),
                    ButtonSegment(value: 'year', label: Text('سالانه')),
                  ],
                  selected: {_selectedPeriod},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedPeriod = newSelection.first;
                    });
                    _loadSalesReport();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _salesData.isEmpty
              ? const Center(child: Text('داده‌ای یافت نشد'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _salesData.length,
                  itemBuilder: (context, index) {
                    final item = _salesData[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          item['date'] != null
                              ? PersianDate.formatIsoDate(
                                  item['date'].toString(),
                                )
                              : '',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${PersianNumber.formatPrice((item['total'] ?? 0).toDouble())} تومان',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            Text(
                              '${PersianNumber.formatNumber(item['count'] ?? 0)} سفارش',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSellerPerformance() {
    return _sellerPerformance.isEmpty
        ? const Center(child: Text('داده‌ای یافت نشد'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _sellerPerformance.length,
            itemBuilder: (context, index) {
              final seller = _sellerPerformance[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(seller['seller_name'] ?? ''),
                  subtitle: Text(
                    '${PersianNumber.formatNumber(seller['order_count'] ?? 0)} سفارش',
                  ),
                  trailing: Text(
                    '${PersianNumber.formatPrice((seller['total_sales'] ?? 0).toDouble())} تومان',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              );
            },
          );
  }
}
