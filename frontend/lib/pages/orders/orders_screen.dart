// Orders Screen - Now displays invoices
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../services/order_service.dart';
import '../../models/order_model.dart';
import '../../utils/persian_number.dart';
import '../../utils/persian_date.dart';
import '../../utils/app_colors.dart';
import '../../utils/status_labels.dart';
import '../../utils/order_total_calculator.dart';
import '../invoices/invoice_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderService _orderService = OrderService();
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    final orders = await _orderService.getOrders(status: _selectedStatus);
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  String _getStatusText(String status) {
    return StatusLabels.getOrderStatus(status);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'delivered':
        return AppColors.primaryGreen;
      case 'returned':
        return AppColors.primaryRed;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سفارش‌ها'),
        ),
        body: Column(
          children: [
            // Filter chips
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('همه', _selectedStatus == null),
                    const SizedBox(width: 8),
                    _buildFilterChip('در انتظار', _selectedStatus == 'pending'),
                    const SizedBox(width: 8),
                    _buildFilterChip('تایید شده', _selectedStatus == 'confirmed'),
                    const SizedBox(width: 8),
                    _buildFilterChip('در حال پردازش', _selectedStatus == 'processing'),
                    const SizedBox(width: 8),
                    _buildFilterChip('تحویل داده شده', _selectedStatus == 'delivered'),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Orders list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _orders.isEmpty
                  ? const Center(child: Text('سفارشی یافت نشد'))
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return _buildOrderCard(order);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (label == 'همه') {
            _selectedStatus = null;
          } else {
            _selectedStatus = _getStatusFromLabel(label);
          }
        });
        _loadOrders();
      },
      selectedColor: AppColors.primaryBlue,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  String? _getStatusFromLabel(String label) {
    switch (label) {
      case 'در انتظار':
        return 'pending';
      case 'تایید شده':
        return 'confirmed';
      case 'در حال پردازش':
        return 'processing';
      case 'تحویل داده شده':
        return 'delivered';
      default:
        return null;
    }
  }

  Widget _buildOrderCard(OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoice: order)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (order.isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'جدید',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${PersianNumber.formatPrice(OrderTotalCalculator.calculateGrandTotal(order))} تومان',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(order.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                PersianDate.formatDateTime(order.createdAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
