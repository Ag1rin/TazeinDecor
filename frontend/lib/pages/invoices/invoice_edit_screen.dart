// Invoice Edit Screen - Edit invoice details with role-based permissions
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../utils/persian_date.dart';
import '../../utils/jalali_date.dart';
import '../../widgets/jalali_date_picker.dart';
import '../../utils/app_colors.dart';

class InvoiceEditScreen extends StatefulWidget {
  final OrderModel invoice;

  const InvoiceEditScreen({super.key, required this.invoice});

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _invoiceNumberController;
  late TextEditingController _subtotalController;
  late TextEditingController _taxAmountController;
  late TextEditingController _discountAmountController;
  late TextEditingController _paymentTermsController;
  late TextEditingController _notesController;

  DateTime? _issueDate;
  DateTime? _dueDate;
  bool _isSaving = false;
  bool _isClerk = false;

  @override
  void initState() {
    super.initState();
    _invoiceNumberController = TextEditingController(
      text: widget.invoice.invoiceNumber ?? widget.invoice.orderNumber,
    );
    _subtotalController = TextEditingController(
      text: (widget.invoice.subtotal ?? widget.invoice.wholesaleAmount ?? 0.0).toString(),
    );
    _taxAmountController = TextEditingController(
      text: widget.invoice.taxAmount.toString(),
    );
    _discountAmountController = TextEditingController(
      text: widget.invoice.discountAmount.toString(),
    );
    _paymentTermsController = TextEditingController(
      text: widget.invoice.paymentTerms ?? '',
    );
    _notesController = TextEditingController(text: widget.invoice.notes ?? '');
    _issueDate = widget.invoice.issueDate;
    _dueDate = widget.invoice.dueDate;

    // Check if user is Clerk (operator) or Admin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      setState(() {
        _isClerk = user?.isOperator == true || user?.isAdmin == true;
      });
    });
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _subtotalController.dispose();
    _taxAmountController.dispose();
    _discountAmountController.dispose();
    _paymentTermsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final invoiceProvider = Provider.of<InvoiceProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // ignore: unused_local_variable
      final user = authProvider.user;

      final invoiceData = {
        'invoice_number': _invoiceNumberController.text,
        'issue_date': _issueDate?.toIso8601String(),
        'due_date': _dueDate?.toIso8601String(),
        'subtotal': double.tryParse(_subtotalController.text) ?? 0.0,
        'tax_amount': double.tryParse(_taxAmountController.text) ?? 0.0,
        'discount_amount':
            double.tryParse(_discountAmountController.text) ?? 0.0,
        'payment_terms': _paymentTermsController.text.isEmpty
            ? null
            : _paymentTermsController.text,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
      };

      bool success;
      if (_isClerk) {
        // Clerk can edit directly
        success = await invoiceProvider.updateInvoice(
          widget.invoice.id,
          invoiceData,
        );
      } else {
        // Seller/Manager requests edit
        success = await invoiceProvider.requestInvoiceEdit(
          widget.invoice.id,
          invoiceData,
        );
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isClerk
                    ? 'فاکتور با موفقیت به‌روزرسانی شد'
                    : 'درخواست ویرایش ارسال شد و در انتظار تایید است',
              ),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                invoiceProvider.error ?? 'خطا در به‌روزرسانی فاکتور',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطا: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _selectIssueDate() async {
    final picked = await showJalaliDatePicker(
      context: context,
      initialDate: _issueDate != null
          ? JalaliDate.fromDateTime(_issueDate!)
          : JalaliDate.now(),
      firstDate: JalaliDate(1400, 1, 1),
      lastDate: JalaliDate(1450, 12, 29),
      helpText: 'انتخاب تاریخ صدور',
    );

    if (picked != null) {
      setState(() {
        _issueDate = picked.toDateTime();
      });
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showJalaliDatePicker(
      context: context,
      initialDate: _dueDate != null
          ? JalaliDate.fromDateTime(_dueDate!)
          : JalaliDate.now(),
      firstDate: JalaliDate(1400, 1, 1),
      lastDate: JalaliDate(1450, 12, 29),
      helpText: 'انتخاب تاریخ سررسید',
    );

    if (picked != null) {
      setState(() {
        _dueDate = picked.toDateTime();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('ویرایش فاکتور ${widget.invoice.effectiveInvoiceNumber}'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isClerk)
                  Card(
                    color: Colors.orange.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ویرایش شما نیاز به تایید منشی دارد',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Invoice Number
                TextFormField(
                  controller: _invoiceNumberController,
                  decoration: const InputDecoration(
                    labelText: 'شماره فاکتور',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفا شماره فاکتور را وارد کنید';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Dates
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectIssueDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تاریخ صدور',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _issueDate != null
                                ? PersianDate.formatDate(_issueDate!)
                                : 'انتخاب تاریخ',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _selectDueDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تاریخ سررسید',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _dueDate != null
                                ? PersianDate.formatDate(_dueDate!)
                                : 'انتخاب تاریخ',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Financial Fields
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _subtotalController,
                        decoration: const InputDecoration(
                          labelText: 'جمع کل',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'لطفا جمع کل را وارد کنید';
                          }
                          if (double.tryParse(value) == null) {
                            return 'لطفا عدد معتبر وارد کنید';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _taxAmountController,
                        decoration: const InputDecoration(
                          labelText: 'مالیات',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null &&
                              value.isNotEmpty &&
                              double.tryParse(value) == null) {
                            return 'لطفا عدد معتبر وارد کنید';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _discountAmountController,
                  decoration: const InputDecoration(
                    labelText: 'تخفیف',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        double.tryParse(value) == null) {
                      return 'لطفا عدد معتبر وارد کنید';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Payment Terms
                TextFormField(
                  controller: _paymentTermsController,
                  decoration: const InputDecoration(
                    labelText: 'شرایط پرداخت',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'یادداشت‌ها',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveInvoice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isClerk ? 'ذخیره تغییرات' : 'ارسال درخواست ویرایش',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
