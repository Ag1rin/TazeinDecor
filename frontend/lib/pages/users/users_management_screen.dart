// Users Management Screen
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../services/user_service.dart';
import '../../services/product_service.dart';
import '../../models/user_model.dart';
import '../../models/category_model.dart';
import '../../utils/persian_number.dart';
import '../../utils/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    final searchQuery = _searchController.text.trim();
    final users = await _userService.getUsers(
      search: searchQuery.isEmpty ? null : searchQuery,
    );
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _addUser() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddUserDialog(),
    );

    if (result != null) {
      final user = await _userService.createUser(
        username: result['username']!,
        password: result['password']!,
        fullName: result['fullName']!,
        mobile: result['mobile']!,
        role: result['role']!,
        nationalId: result['nationalId'],
        storeAddress: result['storeAddress'],
      );

      if (user != null) {
        Fluttertoast.showToast(msg: 'کاربر با موفقیت اضافه شد');
        _loadUsers();
      } else {
        Fluttertoast.showToast(msg: 'خطا در افزودن کاربر');
      }
    }
  }

  Future<void> _editUser(UserModel user) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditUserDialog(user: user),
    );

    if (result != null) {
      final updated = await _userService.updateUser(
        user.id,
        fullName: result['fullName'],
        mobile: result['mobile'],
        role: result['role'],
        credit: result['credit'],
        storeAddress: result['storeAddress'],
        isActive: result['isActive'],
        discountPercentage: result['discountPercentage'],
        discountCategoryIds: result['discountCategoryIds'],
      );

      if (updated != null) {
        Fluttertoast.showToast(msg: 'کاربر با موفقیت به‌روزرسانی شد');
        _loadUsers();
      } else {
        Fluttertoast.showToast(msg: 'خطا در به‌روزرسانی کاربر');
      }
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف کاربر'),
        content: const Text(
          'آیا از حذف این کاربر مطمئن هستید؟ این عمل قابل بازگشت نیست.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
              side: const BorderSide(color: Color(0xFF666666)),
            ),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC3545),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _userService.deleteUser(user.id);
      if (success) {
        Fluttertoast.showToast(msg: 'کاربر حذف شد');
        _loadUsers();
      } else {
        Fluttertoast.showToast(msg: 'خطا در حذف کاربر');
      }
    }
  }

  Future<void> _uploadBusinessCard(UserModel user) async {
    final picker = ImagePicker();
    // Show dialog to choose camera or gallery
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انتخاب منبع تصویر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('دوربین'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('گالری'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final image = await picker.pickImage(source: source);
      if (image != null) {
        final success = await _userService.uploadBusinessCard(
          user.id,
          image.path,
        );
        if (success) {
          Fluttertoast.showToast(msg: 'کارت ویزیت با موفقیت آپلود شد');
          _loadUsers();
        } else {
          Fluttertoast.showToast(msg: 'خطا در آپلود کارت ویزیت');
        }
      }
    }
  }

  String _getRoleText(String role) {
    switch (role) {
      case 'admin':
        return 'مدیر';
      case 'operator':
        return 'اپراتور';
      case 'store_manager':
        return 'مدیر فروشگاه';
      case 'seller':
        return 'فروشنده';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final canCreateSeller =
        authProvider.user?.isStoreManager == true ||
        authProvider.user?.isAdmin == true;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مدیریت کاربران'),
          actions: [
            if (canCreateSeller)
              IconButton(icon: const Icon(Icons.add), onPressed: _addUser),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      'جستجو بر اساس نام، نام کاربری، موبایل یا کد ملی...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            // Users list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                  ? const Center(child: Text('کاربری یافت نشد'))
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return _buildUserCard(user);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(user.fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('نام کاربری: ${user.username}'),
            Text('نقش: ${_getRoleText(user.role)}'),
            Text('موبایل: ${user.mobile}'),
            if (user.isSeller)
              Text('اعتبار: ${PersianNumber.formatPrice(user.credit)} تومان'),
            if (!user.isActive)
              const Text('غیرفعال', style: TextStyle(color: Colors.red)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editUser(user),
            ),
            if (user.isSeller)
              IconButton(
                icon: const Icon(Icons.business_center),
                onPressed: () => _uploadBusinessCard(user),
                tooltip: 'آپلود کارت ویزیت',
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'حذف کاربر',
              onPressed: () => _deleteUser(user),
            ),
          ],
        ),
      ),
    );
  }
}

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _discountPercentageController = TextEditingController();
  String _selectedRole = 'seller';
  bool _obscurePassword = true;
  bool _applyToAllCategories = true;
  List<CategoryModel> _categories = [];
  List<int> _selectedCategoryIds = [];
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _mobileController.dispose();
    _nationalIdController.dispose();
    _storeAddressController.dispose();
    _discountPercentageController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    final productService = ProductService();
    final categories = await productService.getCategories();
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isStoreManager = authProvider.user?.isStoreManager == true;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.person_add,
                      size: 28,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'افزودن کاربر جدید',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 32),
                // Form fields
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Username
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'نام کاربری',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) => value?.isEmpty ?? true
                              ? 'لطفا نام کاربری را وارد کنید'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        // Password with show/hide
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'رمز عبور',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) => value?.isEmpty ?? true
                              ? 'لطفا رمز عبور را وارد کنید'
                              : value!.length < 6
                              ? 'رمز عبور باید حداقل 6 کاراکتر باشد'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        // Full name
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'نام و نام خانوادگی',
                            prefixIcon: const Icon(Icons.badge),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) => value?.isEmpty ?? true
                              ? 'لطفا نام را وارد کنید'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        // Mobile with validation
                        TextFormField(
                          controller: _mobileController,
                          decoration: InputDecoration(
                            labelText: 'شماره موبایل',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            helperText: '11 رقم (مثال: 09123456789)',
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'لطفا شماره موبایل را وارد کنید';
                            }
                            if (value.length != 11) {
                              return 'شماره موبایل باید دقیقاً 11 رقم باشد';
                            }
                            if (!value.startsWith('09')) {
                              return 'شماره موبایل باید با 09 شروع شود';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // National ID
                        TextFormField(
                          controller: _nationalIdController,
                          decoration: InputDecoration(
                            labelText: 'کد ملی (اختیاری)',
                            prefixIcon: const Icon(Icons.credit_card),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Store address
                        TextFormField(
                          controller: _storeAddressController,
                          decoration: InputDecoration(
                            labelText: 'آدرس فروشگاه (اختیاری)',
                            prefixIcon: const Icon(Icons.store),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 2,
                        ),
                        // Discount section (only for sellers and store managers)
                        if (_selectedRole == 'seller' ||
                            _selectedRole == 'store_manager') ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          // Discount header
                          Row(
                            children: [
                              const Icon(
                                Icons.local_offer,
                                color: AppColors.primaryBlue,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'تنظیمات تخفیف',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Discount percentage
                          TextFormField(
                            controller: _discountPercentageController,
                            decoration: InputDecoration(
                              labelText: 'درصد تخفیف (مثال: 3 برای 3%)',
                              prefixIcon: const Icon(Icons.percent),
                              suffixText: '%',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              helperText:
                                  'در صورت خالی بودن، تخفیف اعمال نمی‌شود',
                            ),
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final percentage = double.tryParse(value);
                                if (percentage == null) {
                                  return 'لطفا عدد معتبر وارد کنید';
                                }
                                if (percentage < 0 || percentage > 100) {
                                  return 'درصد تخفیف باید بین 0 تا 100 باشد';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Apply to all categories checkbox
                          CheckboxListTile(
                            title: const Text('اعمال به همه دسته‌بندی‌ها'),
                            value: _applyToAllCategories,
                            onChanged: (value) {
                              setState(() {
                                _applyToAllCategories = value ?? true;
                                if (_applyToAllCategories) {
                                  _selectedCategoryIds.clear();
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          // Category selection (if not all categories)
                          if (!_applyToAllCategories) ...[
                            const SizedBox(height: 8),
                            _isLoadingCategories
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _categories.isEmpty
                                ? const Text(
                                    'دسته‌بندی‌ای یافت نشد',
                                    style: TextStyle(color: Colors.grey),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    constraints: const BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _categories.length,
                                      itemBuilder: (context, index) {
                                        final category = _categories[index];
                                        final isSelected = _selectedCategoryIds
                                            .contains(category.wooId);
                                        return CheckboxListTile(
                                          title: Text(category.name),
                                          value: isSelected,
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedCategoryIds.add(
                                                  category.wooId,
                                                );
                                              } else {
                                                _selectedCategoryIds.remove(
                                                  category.wooId,
                                                );
                                              }
                                            });
                                          },
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                        );
                                      },
                                    ),
                                  ),
                          ],
                        ],
                        const SizedBox(height: 16),
                        // Role dropdown - only seller for store managers
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            labelText: 'نقش',
                            prefixIcon: const Icon(Icons.work),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: isStoreManager
                              ? const [
                                  DropdownMenuItem(
                                    value: 'seller',
                                    child: Text('فروشنده'),
                                  ),
                                ]
                              : const [
                                  DropdownMenuItem(
                                    value: 'seller',
                                    child: Text('فروشنده'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'store_manager',
                                    child: Text('مدیر فروشگاه'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'operator',
                                    child: Text('اپراتور'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'admin',
                                    child: Text('مدیر'),
                                  ),
                                ],
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('لغو'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            // Get discount data
                            double? discountPercentage;
                            List<int>? discountCategoryIds;

                            if (_discountPercentageController.text.isNotEmpty) {
                              discountPercentage = double.tryParse(
                                _discountPercentageController.text,
                              );
                              if (discountPercentage != null &&
                                  discountPercentage > 0) {
                                if (_applyToAllCategories) {
                                  discountCategoryIds =
                                      []; // Empty list means all categories
                                } else {
                                  discountCategoryIds =
                                      _selectedCategoryIds.isNotEmpty
                                      ? _selectedCategoryIds
                                      : null;
                                }
                              }
                            }

                            Navigator.pop(context, {
                              'username': _usernameController.text,
                              'password': _passwordController.text,
                              'fullName': _fullNameController.text,
                              'mobile': _mobileController.text,
                              'role': _selectedRole,
                              'nationalId': _nationalIdController.text.isEmpty
                                  ? null
                                  : _nationalIdController.text,
                              'storeAddress':
                                  _storeAddressController.text.isEmpty
                                  ? null
                                  : _storeAddressController.text,
                              'discountPercentage': discountPercentage,
                              'discountCategoryIds': discountCategoryIds,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'افزودن کاربر',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditUserDialog extends StatefulWidget {
  final UserModel user;

  const EditUserDialog({super.key, required this.user});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _mobileController;
  late TextEditingController _storeAddressController;
  late TextEditingController _creditController;
  late TextEditingController _discountPercentageController;
  String? _selectedRole;
  bool? _isActive;
  bool _applyToAllCategories = true;
  List<int> _selectedCategoryIds = [];
  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = false;
  final ProductService _productService = ProductService();

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _mobileController = TextEditingController(text: widget.user.mobile);
    _storeAddressController = TextEditingController(
      text: widget.user.storeAddress ?? '',
    );
    _creditController = TextEditingController(
      text: widget.user.credit.toStringAsFixed(0),
    );
    _discountPercentageController = TextEditingController(
      text: widget.user.discountPercentage?.toStringAsFixed(0) ?? '',
    );
    _selectedRole = widget.user.role;
    _isActive = widget.user.isActive;
    _selectedCategoryIds = widget.user.discountCategoryIds ?? [];
    _applyToAllCategories = _selectedCategoryIds.isEmpty;
    
    // Load categories if user is seller or store manager
    if (widget.user.role == 'seller' || widget.user.role == 'store_manager') {
      _loadCategories();
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _storeAddressController.dispose();
    _creditController.dispose();
    _discountPercentageController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final categories = await _productService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: const Text('ویرایش کاربر'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'نام و نام خانوادگی',
                  ),
                ),
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(labelText: 'موبایل'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: _storeAddressController,
                  decoration: const InputDecoration(labelText: 'آدرس فروشگاه'),
                  maxLines: 2,
                ),
                if (widget.user.isSeller)
                  TextFormField(
                    controller: _creditController,
                    decoration: const InputDecoration(labelText: 'اعتبار'),
                    keyboardType: TextInputType.number,
                  ),
                if (widget.user.role == 'seller')
                  CheckboxListTile(
                    title: const Text('فعال'),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                  ),
                // Discount section (only for sellers and store managers)
                if (widget.user.role == 'seller' || widget.user.role == 'store_manager')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'تنظیمات تخفیف:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _discountPercentageController,
                        decoration: InputDecoration(
                          labelText: 'درصد تخفیف (مثال: 3)',
                          prefixIcon: const Icon(Icons.discount),
                          suffixText: '%',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final percentage = double.tryParse(value);
                            if (percentage == null || percentage < 0 || percentage > 100) {
                              return 'درصد تخفیف باید بین 0 تا 100 باشد';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('اعمال به همه دسته‌بندی‌ها'),
                        value: _applyToAllCategories,
                        onChanged: (value) {
                          setState(() {
                            _applyToAllCategories = value!;
                            if (_applyToAllCategories) {
                              _selectedCategoryIds.clear();
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (!_applyToAllCategories) ...[
                        const SizedBox(height: 8),
                        _isLoadingCategories
                            ? const Center(child: CircularProgressIndicator())
                            : _categories.isEmpty
                                ? const Text('دسته‌بندی یافت نشد.')
                                : Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _categories.length,
                                      itemBuilder: (context, index) {
                                        final category = _categories[index];
                                        final isSelected = _selectedCategoryIds.contains(category.id);
                                        return CheckboxListTile(
                                          title: Text(category.name),
                                          value: isSelected,
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedCategoryIds.add(category.id);
                                              } else {
                                                _selectedCategoryIds.remove(category.id);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                      ],
                    ],
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
              // Get discount data
              double? discountPercentage;
              List<int>? discountCategoryIds;

              if (_discountPercentageController.text.isNotEmpty) {
                discountPercentage = double.tryParse(
                  _discountPercentageController.text,
                );
                if (discountPercentage != null && discountPercentage > 0) {
                  discountCategoryIds = _applyToAllCategories
                      ? []
                      : _selectedCategoryIds;
                }
              }

              Navigator.pop(context, {
                'fullName': _fullNameController.text,
                'mobile': _mobileController.text,
                'role': _selectedRole,
                'credit': widget.user.isSeller
                    ? double.tryParse(_creditController.text)
                    : null,
                'storeAddress': _storeAddressController.text.isEmpty
                    ? null
                    : _storeAddressController.text,
                'isActive': _isActive,
                'discountPercentage': discountPercentage,
                'discountCategoryIds': discountCategoryIds,
              });
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}
