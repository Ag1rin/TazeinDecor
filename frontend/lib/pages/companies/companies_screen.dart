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
    // Defer loading until after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanies();
    });
  }

  Future<void> _loadCompanies() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    final companies = await _companyService.getCompanies();
    
    if (!mounted) return;
    
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

    if (result != null && mounted) {
      final company = await _companyService.createCompany(result);
      if (company != null && mounted) {
        Fluttertoast.showToast(msg: 'شرکت با موفقیت اضافه شد');
        // Use post frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadCompanies();
          }
        });
      } else if (mounted) {
        Fluttertoast.showToast(msg: 'خطا در افزودن شرکت');
      }
    }
  }

  Future<void> _editCompany(CompanyModel company) async {
    final result = await showDialog<CompanyModel>(
      context: context,
      builder: (context) => EditCompanyDialog(company: company),
    );

    if (result != null && mounted) {
      final updated = await _companyService.updateCompany(company.id, result);
      if (updated != null && mounted) {
        Fluttertoast.showToast(msg: 'شرکت با موفقیت به‌روزرسانی شد');
        // Use post frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadCompanies();
          }
        });
      } else if (mounted) {
        Fluttertoast.showToast(msg: 'خطا در به‌روزرسانی شرکت');
      }
    }
  }

  Future<void> _uploadLogo(CompanyModel company) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      final success = await _companyService.uploadLogo(company.id, image.path);
      if (success && mounted) {
        Fluttertoast.showToast(msg: 'لوگو با موفقیت آپلود شد');
        // Use post frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadCompanies();
          }
        });
      } else if (mounted) {
        Fluttertoast.showToast(msg: 'خطا در آپلود لوگو');
      }
    }
  }

  Future<void> _uploadBrandThumbnail(CompanyModel company) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      final success = await _companyService.uploadBrandThumbnail(company.id, image.path);
      if (success && mounted) {
        Fluttertoast.showToast(msg: 'عکس برند با موفقیت آپلود شد');
        // Use post frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadCompanies();
          }
        });
      } else if (mounted) {
        Fluttertoast.showToast(msg: 'خطا در آپلود عکس برند');
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

    if (confirmed == true && mounted) {
      final success = await _companyService.deleteCompany(company.id);
      if (success && mounted) {
        Fluttertoast.showToast(msg: 'شرکت با موفقیت حذف شد');
        // Use post frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadCompanies();
          }
        });
      } else if (mounted) {
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
                onRefresh: () async {
                  await _loadCompanies();
                },
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
    // Check if this is a virtual company (from WooCommerce brand) or a real company
    final isVirtualCompany = company.id == 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _buildCompanyAvatar(company),
        title: Row(
          children: [
            Expanded(child: Text(company.name)),
            if (isVirtualCompany)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'برند',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (company.mobile != null) Text('موبایل: ${company.mobile}'),
            if (company.address != null) Text('آدرس: ${company.address}'),
            if (company.brandName != null && company.brandName!.isNotEmpty)
              Text(
                'نام برند: ${company.brandName}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            if (isVirtualCompany)
              const Text(
                'برند از ووکامرس',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        trailing: isVirtualCompany
            ? null  // Virtual companies (brands) can't be edited/deleted
            : Row(
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
                  IconButton(
                    icon: const Icon(Icons.photo),
                    onPressed: () => _uploadBrandThumbnail(company),
                    tooltip: 'آپلود عکس برند',
                  ),
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

  Widget _buildCompanyAvatar(CompanyModel company) {
    // Prefer brand thumbnail, then logo, then default icon
    String? imageUrl;
    if (company.brandThumbnail != null && company.brandThumbnail!.isNotEmpty) {
      imageUrl = '${AppConfig.baseUrl}/uploads/${company.brandThumbnail}';
    } else if (company.logo != null && company.logo!.isNotEmpty) {
      imageUrl = '${AppConfig.baseUrl}/uploads/${company.logo}';
    }
    
    if (imageUrl != null) {
      return CircleAvatar(
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // Silently handle image loading errors to prevent rebuild issues
        },
      );
    }
    
    return const CircleAvatar(child: Icon(Icons.business));
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
  final _brandNameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _brandNameController.dispose();
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
                const SizedBox(height: 8),
                TextFormField(
                  controller: _brandNameController,
                  decoration: const InputDecoration(
                    labelText: 'نام برند',
                    hintText: 'نام برند برای تطبیق با محصولات',
                    helperText: 'اگر نام برند با نام برند محصولات یکسان باشد، محصولات به این شرکت اختصاص می‌یابند',
                  ),
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
                    brandName: _brandNameController.text.isEmpty
                        ? null
                        : _brandNameController.text,
                    brandThumbnail: null,
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
  late TextEditingController _brandNameController;

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
    _brandNameController = TextEditingController(
      text: widget.company.brandName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _brandNameController.dispose();
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
                const SizedBox(height: 8),
                TextFormField(
                  controller: _brandNameController,
                  decoration: const InputDecoration(
                    labelText: 'نام برند',
                    hintText: 'نام برند برای تطبیق با محصولات',
                    helperText: 'اگر نام برند با نام برند محصولات یکسان باشد، محصولات به این شرکت اختصاص می‌یابند',
                  ),
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
                  brandName: _brandNameController.text.isEmpty
                      ? null
                      : _brandNameController.text,
                  brandThumbnail: widget.company.brandThumbnail,
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
