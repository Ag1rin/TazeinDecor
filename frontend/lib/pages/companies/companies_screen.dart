library;

// Companies Screen

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../services/company_service.dart';
import '../../config/app_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final CompanyService _companyService = CompanyService();
  List<CompanyModel> _companies = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
    });

    final companies = await _companyService.getCompanies();
    setState(() {
      _companies = companies;
      _isLoading = false;
    });
  }

  Future<void> _addCompany() async {
    final result = await showDialog<CompanyModel>(
      context: context,
      builder: (context) => const AddCompanyDialog(),
    );

    if (result != null) {
      final company = await _companyService.createCompany(result);
      if (company != null) {
        Fluttertoast.showToast(msg: 'شرکت با موفقیت اضافه شد');
        _loadCompanies();
      } else {
        Fluttertoast.showToast(msg: 'خطا در افزودن شرکت');
      }
    }
  }

  Future<void> _editCompany(CompanyModel company) async {
    final result = await showDialog<CompanyModel>(
      context: context,
      builder: (context) => EditCompanyDialog(company: company),
    );

    if (result != null) {
      final updated = await _companyService.updateCompany(company.id, result);
      if (updated != null) {
        Fluttertoast.showToast(msg: 'شرکت با موفقیت به‌روزرسانی شد');
        _loadCompanies();
      } else {
        Fluttertoast.showToast(msg: 'خطا در به‌روزرسانی شرکت');
      }
    }
  }

  Future<void> _uploadLogo(CompanyModel company) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final success = await _companyService.uploadLogo(company.id, image.path);
      if (success) {
        Fluttertoast.showToast(msg: 'لوگو با موفقیت آپلود شد');
        _loadCompanies();
      } else {
        Fluttertoast.showToast(msg: 'خطا در آپلود لوگو');
      }
    }
  }

  /// NEW: Delete company with confirmation
  Future<void> _deleteCompany(CompanyModel company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف شرکت'),
        content: Text('آیا از حذف شرکت "${company.name}" اطمینان دارید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _companyService.deleteCompany(company.id);
      if (success) {
        Fluttertoast.showToast(msg: 'شرکت با موفقیت حذف شد');
        _loadCompanies();
      } else {
        Fluttertoast.showToast(msg: 'خطا در حذف شرکت');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('شرکت‌ها'),
          actions: [
            IconButton(icon: const Icon(Icons.add), onPressed: _addCompany),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _companies.isEmpty
            ? const Center(child: Text('شرکتی یافت نشد'))
            : RefreshIndicator(
                onRefresh: _loadCompanies,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _companies.length,
                  itemBuilder: (context, index) {
                    return _buildCompanyCard(_companies[index]);
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildCompanyCard(CompanyModel company) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: company.logo != null
            ? CircleAvatar(
                backgroundImage: NetworkImage(
                  '${AppConfig.baseUrl}/uploads/${company.logo}',
                ),
              )
            : const CircleAvatar(child: Icon(Icons.business)),
        title: Text(company.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (company.mobile != null) Text('موبایل: ${company.mobile}'),
            if (company.address != null) Text('آدرس: ${company.address}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editCompany(company),
            ),
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: () => _uploadLogo(company),
              tooltip: 'آپلود لوگو',
            ),
            // NEW: Delete button with confirmation
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteCompany(company),
              tooltip: 'حذف شرکت',
            ),
          ],
        ),
      ),
    );
  }
}

class AddCompanyDialog extends StatefulWidget {
  const AddCompanyDialog({super.key});

  @override
  State<AddCompanyDialog> createState() => _AddCompanyDialogState();
}

class _AddCompanyDialogState extends State<AddCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: const Text('افزودن شرکت'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'نام شرکت'),
                  validator: (value) => value?.isEmpty ?? true
                      ? 'لطفا نام شرکت را وارد کنید'
                      : null,
                ),
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(labelText: 'موبایل'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'آدرس'),
                  maxLines: 2,
                ),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'یادداشت'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(
                  context,
                  CompanyModel(
                    id: 0,
                    name: _nameController.text,
                    mobile: _mobileController.text.isEmpty
                        ? null
                        : _mobileController.text,
                    address: _addressController.text.isEmpty
                        ? null
                        : _addressController.text,
                    notes: _notesController.text.isEmpty
                        ? null
                        : _notesController.text,
                    createdAt: DateTime.now(),
                  ),
                );
              }
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
  }
}

class EditCompanyDialog extends StatefulWidget {
  final CompanyModel company;

  const EditCompanyDialog({super.key, required this.company});

  @override
  State<EditCompanyDialog> createState() => _EditCompanyDialogState();
}

class _EditCompanyDialogState extends State<EditCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.company.name);
    _mobileController = TextEditingController(
      text: widget.company.mobile ?? '',
    );
    _addressController = TextEditingController(
      text: widget.company.address ?? '',
    );
    _notesController = TextEditingController(text: widget.company.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: const Text('ویرایش شرکت'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'نام شرکت'),
                ),
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(labelText: 'موبایل'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'آدرس'),
                  maxLines: 2,
                ),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'یادداشت'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                CompanyModel(
                  id: widget.company.id,
                  name: _nameController.text,
                  mobile: _mobileController.text.isEmpty
                      ? null
                      : _mobileController.text,
                  address: _addressController.text.isEmpty
                      ? null
                      : _addressController.text,
                  notes: _notesController.text.isEmpty
                      ? null
                      : _notesController.text,
                  logo: widget.company.logo,
                  createdAt: widget.company.createdAt,
                ),
              );
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}
