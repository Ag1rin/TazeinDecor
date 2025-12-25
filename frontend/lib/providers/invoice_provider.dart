// Invoice Provider
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';

class InvoiceProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();

  List<OrderModel> _invoices = [];
  bool _isLoading = false;
  String? _error;
  String? _searchQuery;
  String? _selectedStatus;

  List<OrderModel> get invoices => _invoices;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get searchQuery => _searchQuery;
  String? get selectedStatus => _selectedStatus;

  // Filter invoices by status
  List<OrderModel> get pendingCompletionInvoices =>
      _invoices.where((inv) => inv.status == 'pending_completion').toList();

  List<OrderModel> get inProgressInvoices =>
      _invoices.where((inv) => inv.status == 'in_progress').toList();

  List<OrderModel> get settledInvoices =>
      _invoices.where((inv) => inv.status == 'settled').toList();

  // Load all invoices
  Future<void> loadInvoices({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _invoices = await _orderService.getOrders(status: status, perPage: 100);
      _selectedStatus = status;
      _error = null;
    } catch (e) {
      _error = 'خطا در بارگذاری فاکتورها: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search invoices
  Future<void> searchInvoices({
    String? query,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    _searchQuery = query;
    _selectedStatus = status;
    notifyListeners();

    try {
      _invoices = await _orderService.searchInvoices(
        query: query,
        status: status,
        startDate: startDate,
        endDate: endDate,
      );
      _error = null;
    } catch (e) {
      _error = 'خطا در جستجوی فاکتورها: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update invoice status
  Future<bool> updateInvoiceStatus(int orderId, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _orderService.updateInvoiceStatus(orderId, status);
      if (success) {
        // Reload invoices
        await loadInvoices(status: _selectedStatus);
        _error = null;
      }
      return success;
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      _error = errorMessage.isNotEmpty
          ? errorMessage
          : 'خطا در به‌روزرسانی وضعیت';
      print('❌ Invoice status update error: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update invoice (for Clerk - direct edit)
  Future<bool> updateInvoice(
    int orderId,
    Map<String, dynamic> invoiceData,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _orderService.updateInvoice(orderId, invoiceData);
      if (success) {
        // Reload invoices
        await loadInvoices(status: _selectedStatus);
      }
      return success;
    } catch (e) {
      _error = 'خطا در به‌روزرسانی فاکتور: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Request invoice edit (for Seller/Manager - requires approval)
  Future<bool> requestInvoiceEdit(
    int orderId,
    Map<String, dynamic> invoiceData,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _orderService.updateInvoice(orderId, invoiceData);
      if (success) {
        // Reload invoices
        await loadInvoices(status: _selectedStatus);
      }
      return success;
    } catch (e) {
      _error = 'خطا در درخواست ویرایش: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Approve invoice edit (for Clerk)
  Future<bool> approveInvoiceEdit(
    int orderId,
    Map<String, dynamic> invoiceData,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _orderService.approveInvoiceEdit(
        orderId,
        invoiceData,
      );
      if (success) {
        // Reload invoices
        await loadInvoices(status: _selectedStatus);
      }
      return success;
    } catch (e) {
      _error = 'خطا در تایید ویرایش: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get single invoice
  Future<OrderModel?> getInvoice(int orderId) async {
    try {
      return await _orderService.getOrder(orderId);
    } catch (e) {
      _error = 'خطا در دریافت فاکتور: ${e.toString()}';
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = null;
    _selectedStatus = null;
    notifyListeners();
  }
}
