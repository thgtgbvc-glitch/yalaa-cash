import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart' hide Banner;
import 'package:yalla_cash_core/yalla_cash_core.dart' as core show Banner;

const _adminPointAdjustmentNote = 'Admin adjustment';

class YallaCashAdminApp extends StatefulWidget {
  const YallaCashAdminApp(
      {super.key, this.store, this.runtime, this.skipLogin = false});

  final YallaCashStore? store;
  final YallaCashRuntime? runtime;
  final bool skipLogin;

  @override
  State<YallaCashAdminApp> createState() => _YallaCashAdminAppState();
}

class _YallaCashAdminAppState extends State<YallaCashAdminApp> {
  late final YallaCashRuntime? runtime = widget.runtime ??
      (widget.store == null ? YallaCashRuntime.fromEnvironment() : null);
  late final YallaCashStore? store = widget.store ?? runtime?.demoStore;
  late final YallaCashRepository repository =
      runtime?.repository ?? InMemoryYallaCashRepository(store!);
  late final AdminAppCubit adminCubit = AdminAppCubit(repository);
  late bool authenticated = widget.skipLogin;
  var darkMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipLogin) unawaited(adminCubit.refresh());
  }

  @override
  void dispose() {
    adminCubit.close();
    if (widget.store == null && widget.runtime == null) {
      runtime?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AdminAppState>(
        stream: adminCubit.stream,
        initialData: adminCubit.state,
        builder: (context, snapshot) {
          final state = snapshot.data ?? adminCubit.state;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'لوحة تحكم يلا كاش',
            theme: buildYallaTheme(Brightness.light),
            darkTheme: buildYallaTheme(Brightness.dark),
            themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            ),
            home: authenticated
                ? AdminShell(
                    cubit: adminCubit,
                    state: state,
                    repository: repository,
                    darkMode: darkMode,
                    onDarkModeChanged: (value) =>
                        setState(() => darkMode = value),
                    onLogout: _logout,
                  )
                : AdminLoginScreen(
                    cubit: adminCubit,
                    state: state,
                    onAuthenticated: () =>
                        setState(() => authenticated = true)),
          );
        },
      );

  Future<void> _logout() async {
    await adminCubit.logout();
    if (mounted) setState(() => authenticated = false);
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    required this.cubit,
    required this.state,
    required this.onAuthenticated,
    super.key,
  });

  final AdminAppCubit cubit;
  final AdminAppState state;
  final VoidCallback onAuthenticated;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final emailController = TextEditingController(text: 'admin@yallacash.app');
  final passwordController = TextEditingController(text: 'admin123');
  String? error;
  bool submitting = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = submitting || widget.state.status == LoadStatus.loading;
    final failure = error ?? widget.state.failure?.message;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: YallaCashLogo(height: 112)),
                    const SizedBox(height: 18),
                    Text('لوحة تحكم يلا كاش',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('دخول الإدارة', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('admin-email'),
                      controller: emailController,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.mail_outline_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('admin-password'),
                      controller: passwordController,
                      obscureText: true,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: Icon(Icons.lock_outline_rounded)),
                    ),
                    if (failure != null) ...[
                      const SizedBox(height: 10),
                      Text(failure,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                        key: const Key('admin-login'),
                        onPressed: loading ? null : _login,
                        child: const Text('تسجيل الدخول')),
                    const SizedBox(height: 10),
                    Text('بيانات العرض مدخلة مسبقاً',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() {
      error = null;
      submitting = true;
    });
    await widget.cubit.signIn(
      email: emailController.text.trim(),
      password: passwordController.text,
    );
    if (!mounted) return;
    if (widget.cubit.state.isAuthenticated) {
      widget.onAuthenticated();
    } else {
      submitting = false;
      final failure = widget.cubit.state.failure;

      setState(() {
        error = failure == null
            ? 'فشل تسجيل الدخول.'
            : '${failure.message} (${failure.code})';
      });
    }
  }
}

enum AdminSection {
  overview('نظرة عامة', Icons.dashboard_outlined),
  cashRequests('طلبات الكاش', Icons.payments_outlined),
  customers('المستخدمون', Icons.people_outline_rounded),
  stores('المحلات', Icons.storefront_outlined),
  governorates('المحافظات', Icons.location_on_outlined),
  banners('الإعلانات', Icons.campaign_outlined),
  products('المنتجات الرقمية', Icons.redeem_outlined),
  merchantAccounts('حسابات المحلات', Icons.badge_outlined),
  settlements('التحاسب الشهري', Icons.account_balance_outlined),
  settings('الإعدادات', Icons.settings_outlined);

  const AdminSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class AdminShell extends StatefulWidget {
  const AdminShell(
      {required this.cubit,
      required this.state,
      required this.repository,
      required this.darkMode,
      required this.onDarkModeChanged,
      required this.onLogout,
      super.key});

  final AdminAppCubit cubit;
  final AdminAppState state;
  final YallaCashRepository repository;
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onLogout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  var section = AdminSection.overview;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final content = _AdminContent(
      section: section,
      cubit: widget.cubit,
      state: widget.state,
      repository: widget.repository,
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !wide,
        title: Text(section.label,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: widget.darkMode ? 'الوضع الفاتح' : 'الوضع الداكن',
            onPressed: () => widget.onDarkModeChanged(!widget.darkMode),
            icon: Icon(widget.darkMode
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
          ),
          IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      drawer: wide
          ? null
          : Builder(
              builder: (drawerContext) => Drawer(
                child: SafeArea(
                  child: _AdminNavigation(
                    selected: section,
                    onSelected: (value) {
                      _select(value);
                      Navigator.pop(drawerContext);
                    },
                  ),
                ),
              ),
            ),
      body: wide
          ? Row(
              children: [
                SizedBox(
                    width: 250,
                    child: _AdminNavigation(
                        selected: section, onSelected: _select)),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }

  void _select(AdminSection value) {
    setState(() => section = value);
  }
}

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({required this.selected, required this.onSelected});

  final AdminSection selected;
  final ValueChanged<AdminSection> onSelected;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 14, 12, 22),
              child: Row(
                children: [
                  YallaCashLogo(height: 42, markOnly: true),
                  SizedBox(width: 10),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('يلا كاش',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 18)),
                        Text('لوحة التحكم', style: TextStyle(fontSize: 11))
                      ]),
                ],
              ),
            ),
            for (final item in AdminSection.values)
              ListTile(
                selected: selected == item,
                selectedTileColor:
                    Theme.of(context).colorScheme.primaryContainer,
                leading: Icon(item.icon),
                title: Text(item.label),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () => onSelected(item),
              ),
          ],
        ),
      );
}

class _AdminContent extends StatelessWidget {
  const _AdminContent({
    required this.section,
    required this.cubit,
    required this.state,
    required this.repository,
  });

  final AdminSection section;
  final AdminAppCubit cubit;
  final AdminAppState state;
  final YallaCashRepository repository;

  @override
  Widget build(BuildContext context) => switch (section) {
        AdminSection.overview => AdminOverview(state: state),
        AdminSection.cashRequests => CashRequestsAdmin(
            cubit: cubit,
            requests: state.cashRequests,
            customers: state.customers,
          ),
        AdminSection.customers => CustomersAdmin(
            cubit: cubit,
            customers: state.customers,
          ),
        AdminSection.stores => StoresAdmin(
            cubit: cubit,
            stores: state.stores,
          ),
        AdminSection.governorates => GovernoratesAdmin(repository: repository),
        AdminSection.banners => BannersAdmin(repository: repository),
        AdminSection.products => ProductsAdmin(
            cubit: cubit,
            products: state.products,
          ),
        AdminSection.merchantAccounts => MerchantAccountsAdmin(
            cubit: cubit,
            stores: state.stores,
            accounts: state.merchantAccounts,
          ),
        AdminSection.settlements => SettlementsAdmin(
            cubit: cubit,
            settlements: state.settlements,
          ),
        AdminSection.settings => SettingsAdmin(
            cubit: cubit,
            pointValueSyp: state.pointValueSyp,
          ),
      };
}

class AdminOverview extends StatelessWidget {
  const AdminOverview({required this.state, super.key});

  final AdminAppState state;

  @override
  Widget build(BuildContext context) {
    final overview = state.overview;
    if (overview == null) {
      return _AdminPage(
        key: const ValueKey('admin-overview'),
        children: const [LinearProgressIndicator()],
      );
    }
    return _AdminPage(
      key: const ValueKey('admin-overview'),
      children: [
        const _PageTitle(
            title: 'نظرة عامة', subtitle: 'ملخص أداء منصة يلا كاش'),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050
                ? 4
                : constraints.maxWidth >= 600
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 3.4 : 2.0,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _KpiCard(
                    label: 'المستخدمون',
                    value: formatNumber(overview.customers),
                    icon: Icons.people_outline_rounded,
                    color: YallaColors.primaryStrong),
                _KpiCard(
                    label: 'المبيعات المسجلة',
                    value: '${formatNumber(overview.totalSalesSyp)} ل.س',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFF0E8C79)),
                _KpiCard(
                    label: 'دخل المنصة',
                    value: '${formatNumber(overview.platformRevenueSyp)} ل.س',
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF7C6CF0)),
                _KpiCard(
                    label: 'طلبات كاش معلقة',
                    value: formatNumber(overview.pendingCashRequests),
                    icon: Icons.notifications_active_outlined,
                    color: YallaColors.gold),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text('آخر العمليات',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _TableCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('المحل')),
              DataColumn(label: Text('الفاتورة')),
              DataColumn(label: Text('النقاط')),
              DataColumn(label: Text('التاريخ'))
            ],
            rows: const <LoyaltyTransaction>[]
                .take(8)
                .map((item) => DataRow(cells: [
                      DataCell(Text(item.storeName)),
                      DataCell(Text('${formatNumber(item.amountSyp)} ل.س')),
                      DataCell(
                          Text('+${formatNumber(item.customerPointsEarned)}')),
                      DataCell(Text(formatDate(item.createdAt))),
                    ]))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class CashRequestsAdmin extends StatelessWidget {
  const CashRequestsAdmin({
    required this.cubit,
    required this.requests,
    required this.customers,
    super.key,
  });

  final AdminAppCubit cubit;
  final List<CashRedemptionRequest> requests;
  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    return _AdminPage(children: [
      const _PageTitle(
          title: 'طلبات استبدال النقاط بكاش',
          subtitle: 'راجع الطلب ثم أكد التسليم النقدي أو ارفضه'),
      const SizedBox(height: 18),
      if (requests.isEmpty)
        const _EmptyAdmin(
            icon: Icons.check_circle_outline_rounded,
            text: 'لا توجد طلبات معلقة')
      else
        ...requests.map((request) {
          final customer = _customerForRequest(request, customers);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 14,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const CircleAvatar(child: Icon(Icons.payments_outlined)),
                  SizedBox(
                      width: 220,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            Text(
                                '${formatNumber(request.pointsRequested)} نقطة · ${formatNumber(request.cashValueSyp)} ل.س')
                          ])),
                  SizedBox(
                    width: 140,
                    child: FilledButton.tonalIcon(
                      onPressed: () => cubit.resolveCashRequest(request, true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('حل الطلب'),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: OutlinedButton.icon(
                      onPressed: () => cubit.resolveCashRequest(request, false),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رفض الطلب'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
    ]);
  }
}

class CustomersAdmin extends StatelessWidget {
  const CustomersAdmin({
    required this.cubit,
    required this.customers,
    super.key,
  });

  final AdminAppCubit cubit;
  final List<Customer> customers;

  @override
  Widget build(BuildContext context) => _AdminPage(children: [
        const _PageTitle(
            title: 'المستخدمون', subtitle: 'إدارة أرصدة الزبائن وحساباتهم'),
        const SizedBox(height: 18),
        _TableCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('الاسم')),
              DataColumn(label: Text('المحافظة')),
              DataColumn(label: Text('الرصيد')),
              DataColumn(label: Text('تاريخ الانضمام')),
              DataColumn(label: Text('إجراءات'))
            ],
            rows: customers
                .map((customer) => DataRow(cells: [
                      DataCell(Text(customer.name,
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text(customer.governorate)),
                      DataCell(
                          Text('${formatNumber(customer.pointsBalance)} نقطة')),
                      DataCell(Text(formatDate(customer.createdAt))),
                      DataCell(Wrap(spacing: 6, children: [
                        IconButton(
                            tooltip: 'منح نقاط',
                            onPressed: () =>
                                _pointsDialog(context, customer, true),
                            icon: const Icon(Icons.add_circle_outline_rounded)),
                        IconButton(
                            tooltip: 'خصم نقاط',
                            onPressed: () =>
                                _pointsDialog(context, customer, false),
                            icon: const Icon(
                                Icons.remove_circle_outline_rounded)),
                        IconButton(
                            tooltip: 'حذف',
                            onPressed: () => _deleteCustomer(context, customer),
                            icon: Icon(Icons.delete_outline_rounded,
                                color: Theme.of(context).colorScheme.error)),
                      ])),
                    ]))
                .toList(),
          ),
        ),
      ]);

  Future<void> _pointsDialog(
      BuildContext context, Customer customer, bool grant) async {
    final controller = TextEditingController();
    final points = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(grant
            ? 'منح نقاط إلى ${customer.name}'
            : 'خصم نقاط من ${customer.name}'),
        content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد النقاط')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, int.tryParse(controller.text)),
              child: const Text('تأكيد')),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (points == null || points <= 0) return;
    if (grant) {
      await cubit.grantPoints(customer, points, _adminPointAdjustmentNote);
    } else {
      await cubit.deductPoints(customer, points, _adminPointAdjustmentNote);
    }
  }

  Future<void> _deleteCustomer(BuildContext context, Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content:
            Text('هل تريد حذف حساب ${customer.name} وسجلات العرض المرتبطة به؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) await cubit.deleteCustomer(customer);
  }
}

class GovernoratesAdmin extends StatefulWidget {
  const GovernoratesAdmin({required this.repository, super.key});

  final YallaCashRepository repository;

  @override
  State<GovernoratesAdmin> createState() => _GovernoratesAdminState();
}

class _GovernoratesAdminState extends State<GovernoratesAdmin> {
  List<Governorate> items = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final loaded = await widget.repository.listAdminGovernorates();
      if (!mounted) return;
      setState(() {
        items = loaded
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذر تحميل المحافظات.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => _AdminPage(
        children: [
          _PageTitle(
            title: 'إدارة المحافظات',
            subtitle: 'تحكم بالمحافظات المتاحة وترتيب ظهورها للعملاء',
            action: FilledButton.icon(
              onPressed: () => _editGovernorate(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة محافظة'),
            ),
          ),
          const SizedBox(height: 18),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            Center(child: Text(error!))
          else if (items.isEmpty)
            const Center(child: Text('لا توجد محافظات بعد.'))
          else
            Card(
              child: Column(
                children: [
                  const ListTile(
                    title: Text('اسم المحافظة',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('الحالة · ترتيب الظهور'),
                    trailing: Text('تعديل',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const Divider(height: 1),
                  ...items.map(
                    (item) => ListTile(
                      leading:
                          CircleAvatar(child: Text('${item.displayOrder}')),
                      title: Text(item.nameAr,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(item.isActive
                          ? 'نشطة · الترتيب ${item.displayOrder}'
                          : 'غير نشطة · الترتيب ${item.displayOrder}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                              value: item.isActive,
                              onChanged: (value) => _toggle(item, value)),
                          IconButton(
                              tooltip: 'تعديل',
                              onPressed: () => _editGovernorate(context, item),
                              icon: const Icon(Icons.edit_outlined)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

  Future<void> _toggle(Governorate item, bool isActive) async {
    await widget.repository
        .updateGovernorate(item.copyWith(isActive: isActive));
    await _refresh();
  }

  Future<void> _editGovernorate(BuildContext context,
      [Governorate? item]) async {
    final name = TextEditingController(text: item?.nameAr ?? '');
    final order = TextEditingController(
        text: '${item?.displayOrder ?? (items.length + 1)}');
    var active = item?.isActive ?? false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'إضافة محافظة' : 'تعديل المحافظة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم المحافظة')),
              const SizedBox(height: 12),
              TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'ترتيب الظهور')),
              SwitchListTile(
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value),
                  title: const Text('نشطة')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    final nameValue = name.text.trim();
    final orderValue = int.tryParse(order.text) ?? items.length + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      order.dispose();
    });
    if (saved != true || nameValue.isEmpty) return;
    final next = Governorate(
      id: item?.id ?? 'gov-${DateTime.now().microsecondsSinceEpoch}',
      nameAr: nameValue,
      isActive: active,
      displayOrder: orderValue,
      createdAt: item?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (item == null) {
      await widget.repository.createGovernorate(next);
    } else {
      await widget.repository.updateGovernorate(next);
    }
    await _refresh();
  }
}

class BannersAdmin extends StatefulWidget {
  const BannersAdmin({required this.repository, super.key});

  final YallaCashRepository repository;

  @override
  State<BannersAdmin> createState() => _BannersAdminState();
}

class _BannersAdminState extends State<BannersAdmin> {
  static const allGovernoratesValue = '__all_governorates__';

  List<core.Banner> items = const [];
  List<Governorate> governorates = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final loadedGovernorates =
          await widget.repository.listAdminGovernorates();
      final loadedBanners = await widget.repository.listAdminBanners();
      if (!mounted) return;
      setState(() {
        governorates = loadedGovernorates.toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        items = loadedBanners.toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذر تحميل الإعلانات.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => _AdminPage(
        children: [
          _PageTitle(
            title: 'إعلانات الصفحة الرئيسية',
            subtitle:
                'إدارة الشرائح الترويجية حسب المحافظة والحالة وجدولة الظهور',
            action: FilledButton.icon(
              onPressed: loading ? null : () => _editBanner(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة إعلان'),
            ),
          ),
          const SizedBox(height: 18),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            _BannerAdminMessage(message: error!, onRetry: _refresh)
          else if (items.isEmpty)
            const _EmptyAdmin(
                icon: Icons.campaign_outlined, text: 'لا توجد إعلانات بعد.')
          else
            ...items.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: _BannerImageThumb(url: item.imageUrl),
                  title: Text(item.title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_bannerSummary(item)),
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Switch(
                          value: item.isActive,
                          onChanged: (value) => _toggle(item, value)),
                      IconButton(
                        tooltip: 'تعديل',
                        onPressed: () => _editBanner(context, item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        onPressed: () => _deleteBanner(item),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );

  String _bannerSummary(core.Banner item) {
    final status = item.isActive ? 'نشط' : 'متوقف';
    final governorate = item.governorateId == null
        ? 'كل المحافظات'
        : _governorateName(item.governorateId!);
    final schedule = _scheduleLabel(item);
    return [
      if (item.subtitle?.trim().isNotEmpty ?? false) item.subtitle!.trim(),
      '$status · $governorate · الترتيب ${item.displayOrder}',
      if (schedule != null) schedule,
    ].join('\n');
  }

  String _governorateName(String id) {
    for (final governorate in governorates) {
      if (governorate.id == id) return governorate.nameAr;
    }
    return 'محافظة محددة';
  }

  String? _scheduleLabel(core.Banner item) {
    final start = item.startsAt == null ? null : _formatDate(item.startsAt!);
    final end = item.endsAt == null ? null : _formatDate(item.endsAt!);
    if (start == null && end == null) return null;
    if (start != null && end != null) return 'من $start إلى $end';
    if (start != null) return 'يبدأ $start';
    return 'ينتهي $end';
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _deleteBanner(core.Banner item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: Text('هل تريد حذف "${item.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.deleteBanner(item.id);
      await _refresh();
    } catch (_) {
      _showBannerSnack('تعذر حذف الإعلان.');
    }
  }

  Future<void> _toggle(core.Banner item, bool isActive) async {
    try {
      await widget.repository.updateBanner(item.copyWith(isActive: isActive));
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديث حالة الإعلان.')));
    }
  }

  Future<void> _editBanner(BuildContext context, [core.Banner? item]) async {
    final title = TextEditingController(text: item?.title ?? '');
    final subtitle = TextEditingController(text: item?.subtitle ?? '');
    final imageUrl = TextEditingController(text: item?.imageUrl ?? '');
    final targetUrl = TextEditingController(text: item?.targetUrl ?? '');
    final order = TextEditingController(
        text: '${item?.displayOrder ?? (items.length + 1)}');
    final startsAt =
        TextEditingController(text: item?.startsAt?.toIso8601String() ?? '');
    final endsAt =
        TextEditingController(text: item?.endsAt?.toIso8601String() ?? '');
    var active = item?.isActive ?? true;
    var governorateChoice = item?.governorateId ?? allGovernoratesValue;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'إضافة إعلان' : 'تعديل الإعلان'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'العنوان')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: subtitle,
                      decoration:
                          const InputDecoration(labelText: 'العنوان الفرعي')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: imageUrl,
                    decoration: const InputDecoration(labelText: 'رابط الصورة'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (imageUrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _BannerImagePreview(url: imageUrl.text.trim()),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                      controller: targetUrl,
                      decoration:
                          const InputDecoration(labelText: 'رابط الهدف')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: governorateChoice,
                    decoration: const InputDecoration(labelText: 'المحافظة'),
                    items: [
                      const DropdownMenuItem(
                          value: allGovernoratesValue,
                          child: Text('كل المحافظات')),
                      ...governorates.map(
                        (governorate) => DropdownMenuItem(
                            value: governorate.id,
                            child: Text(governorate.nameAr)),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() =>
                        governorateChoice = value ?? allGovernoratesValue),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: order,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'ترتيب الظهور')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: startsAt,
                      decoration: const InputDecoration(
                          labelText: 'وقت البداية اختياري ISO')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: endsAt,
                      decoration: const InputDecoration(
                          labelText: 'وقت النهاية اختياري ISO')),
                  SwitchListTile(
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                    title: const Text('نشط'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );

    final titleValue = title.text.trim();
    final subtitleValue = subtitle.text.trim();
    final imageUrlValue = imageUrl.text.trim();
    final targetUrlValue = targetUrl.text.trim();
    final orderValue = int.tryParse(order.text) ?? items.length + 1;
    final startsAtValue = _parseOptionalDate(startsAt.text);
    final endsAtValue = _parseOptionalDate(endsAt.text);
    final startsAtInvalid =
        startsAt.text.trim().isNotEmpty && startsAtValue == null;
    final endsAtInvalid = endsAt.text.trim().isNotEmpty && endsAtValue == null;
    title.dispose();
    subtitle.dispose();
    imageUrl.dispose();
    targetUrl.dispose();
    order.dispose();
    startsAt.dispose();
    endsAt.dispose();

    if (saved != true) return;
    if (titleValue.isEmpty || imageUrlValue.isEmpty) {
      _showBannerSnack('أدخل عنوان الإعلان ورابط الصورة.');
      return;
    }
    if (!_isWebImageUrl(imageUrlValue)) {
      _showBannerSnack('رابط الصورة يجب أن يبدأ بـ http أو https.');
      return;
    }
    if (startsAtInvalid || endsAtInvalid) {
      _showBannerSnack('صيغة التاريخ يجب أن تكون ISO صالحة.');
      return;
    }
    if (startsAtValue != null &&
        endsAtValue != null &&
        endsAtValue.isBefore(startsAtValue)) {
      _showBannerSnack('وقت النهاية يجب أن يكون بعد وقت البداية.');
      return;
    }

    final next = core.Banner(
      id: item?.id ?? 'banner-${DateTime.now().microsecondsSinceEpoch}',
      title: titleValue,
      subtitle: subtitleValue.isEmpty ? null : subtitleValue,
      imageUrl: imageUrlValue,
      targetUrl: targetUrlValue.isEmpty ? null : targetUrlValue,
      placement: item?.placement ?? 'home',
      style: item?.style ?? 'promo',
      isActive: active,
      displayOrder: orderValue,
      governorateId:
          governorateChoice == allGovernoratesValue ? null : governorateChoice,
      startsAt: startsAtValue,
      endsAt: endsAtValue,
      createdAt: item?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (item == null) {
        await widget.repository.createBanner(next);
      } else {
        await widget.repository.updateBanner(next);
      }
      await _refresh();
    } catch (_) {
      _showBannerSnack('تعذر حفظ الإعلان.');
    }
  }

  DateTime? _parseOptionalDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }

  bool _isWebImageUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  void _showBannerSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BannerImageThumb extends StatelessWidget {
  const _BannerImageThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 84,
          height: 72,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
      );
}

class _BannerImagePreview extends StatelessWidget {
  const _BannerImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 6,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child:
                  const Center(child: Icon(Icons.image_not_supported_outlined)),
            ),
          ),
        ),
      );
}

class _BannerAdminMessage extends StatelessWidget {
  const _BannerAdminMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
              TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
}

class StoresAdmin extends StatelessWidget {
  const StoresAdmin({
    required this.cubit,
    required this.stores,
    super.key,
  });

  final AdminAppCubit cubit;
  final List<PartnerStore> stores;

  @override
  Widget build(BuildContext context) => _AdminPage(children: [
        _PageTitle(
            title: 'إدارة المحلات',
            subtitle: 'المحل الحصري ونسبة العمولة ومعلومات الظهور',
            action: FilledButton.icon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة محل'))),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth >= 900
              ? (constraints.maxWidth - 24) / 3
              : constraints.maxWidth >= 560
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: stores
                .map((partner) => SizedBox(
                    width: width,
                    child: _StoreAdminCard(cubit: cubit, partner: partner)))
                .toList(),
          );
        }),
      ]);

  Future<void> _create(BuildContext context) async {
    final created = await _showStoreEditor(context);
    if (created != null) await cubit.createStore(created);
  }
}

class _StoreAdminCard extends StatelessWidget {
  const _StoreAdminCard({required this.cubit, required this.partner});

  final AdminAppCubit cubit;
  final PartnerStore partner;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(child: Icon(AdminSection.stores.icon)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(partner.name,
                        style: const TextStyle(fontWeight: FontWeight.w900))),
                Chip(label: Text('${partner.commissionRate}%'))
              ]),
              const SizedBox(height: 10),
              Text(partner.category,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  partner.description.isEmpty
                      ? 'لا يوجد وصف'
                      : partner.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(partner.location,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: () => _edit(context),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تعديل'))),
            ],
          ),
        ),
      );

  Future<void> _edit(BuildContext context) async {
    final name = TextEditingController(text: partner.name);
    final category = TextEditingController(text: partner.category);
    final rate = TextEditingController(text: partner.commissionRate.toString());
    final location = TextEditingController(text: partner.location);
    final description = TextEditingController(text: partner.description);
    final updated = await showDialog<PartnerStore>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل المحل'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم المحل')),
              const SizedBox(height: 10),
              TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'الفئة')),
              const SizedBox(height: 10),
              TextField(
                  controller: rate,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'نسبة العمولة %')),
              const SizedBox(height: 10),
              TextField(
                  controller: location,
                  decoration: const InputDecoration(labelText: 'الموقع')),
              const SizedBox(height: 10),
              TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'الوصف')),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(
                context,
                partner.copyWith(
                    name: name.text.trim(),
                    category: category.text.trim(),
                    commissionRate:
                        double.tryParse(rate.text) ?? partner.commissionRate,
                    location: location.text.trim(),
                    description: description.text.trim())),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    name.dispose();
    category.dispose();
    rate.dispose();
    location.dispose();
    description.dispose();

    if (updated != null) await cubit.updateStore(updated);
  }
}

class ProductsAdmin extends StatelessWidget {
  const ProductsAdmin({
    required this.cubit,
    required this.products,
    super.key,
  });

  final AdminAppCubit cubit;
  final List<DigitalProduct> products;

  @override
  Widget build(BuildContext context) => _AdminPage(children: [
        _PageTitle(
            title: 'المنتجات الرقمية',
            subtitle: 'إدارة خيارات استبدال النقاط',
            action: FilledButton.icon(
                onPressed: () => _createProduct(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة منتج'))),
        const SizedBox(height: 18),
        _TableCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('المنتج')),
              DataColumn(label: Text('التكلفة')),
              DataColumn(label: Text('رقم هاتف')),
              DataColumn(label: Text('الحالة')),
              DataColumn(label: Text(''))
            ],
            rows: products
                .map((product) => DataRow(cells: [
                      DataCell(Text(product.name,
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(
                          Text('${formatNumber(product.costInPoints)} نقطة')),
                      DataCell(Icon(product.requiresPhoneNumber
                          ? Icons.check_circle_rounded
                          : Icons.remove_rounded)),
                      DataCell(Chip(
                          label: Text(product.isActive ? 'نشط' : 'متوقف'))),
                      DataCell(IconButton(
                          onPressed: () => _editProduct(context, product),
                          icon: const Icon(Icons.edit_outlined))),
                    ]))
                .toList(),
          ),
        ),
      ]);

  Future<void> _editProduct(
      BuildContext context, DigitalProduct product) async {
    final name = TextEditingController(text: product.name);
    final cost = TextEditingController(text: product.costInPoints.toString());
    var needsPhone = product.requiresPhoneNumber;
    var active = product.isActive;
    final updated = await showDialog<DigitalProduct>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
                title: const Text('تعديل المنتج'),
                content: SizedBox(
                    width: 460,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          decoration:
                              const InputDecoration(labelText: 'اسم المنتج')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: cost,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'التكلفة بالنقاط')),
                      SwitchListTile(
                          value: needsPhone,
                          onChanged: (value) =>
                              setLocalState(() => needsPhone = value),
                          title: const Text('يتطلب رقم هاتف')),
                      SwitchListTile(
                          value: active,
                          onChanged: (value) =>
                              setLocalState(() => active = value),
                          title: const Text('المنتج نشط')),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(
                          context,
                          product.copyWith(
                              name: name.text.trim(),
                              costInPoints: int.tryParse(cost.text) ??
                                  product.costInPoints,
                              requiresPhoneNumber: needsPhone,
                              isActive: active)),
                      child: const Text('حفظ')),
                ],
              )),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      cost.dispose();
    });
    if (updated != null) await cubit.updateProduct(updated);
  }

  Future<void> _createProduct(BuildContext context) async {
    final created = await _showProductEditor(context);
    if (created != null) await cubit.createProduct(created);
  }
}

class MerchantAccountsAdmin extends StatelessWidget {
  const MerchantAccountsAdmin({
    required this.cubit,
    required this.stores,
    required this.accounts,
    super.key,
  });

  final AdminAppCubit cubit;
  final List<PartnerStore> stores;
  final List<MerchantAccount> accounts;

  @override
  Widget build(BuildContext context) => _AdminPage(
        children: [
          const _PageTitle(
            title: 'حسابات دخول المحلات',
            subtitle: 'كل محل يمكن أن يمتلك أكثر من حساب أو جهاز',
          ),
          const SizedBox(height: 18),
          ...stores.map((partner) {
            final storeAccounts =
                accounts.where((item) => item.storeId == partner.id).toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 150,
                      height: 44,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _addAccount(context, partner),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('توليد حساب'),
                      ),
                    ),
                    if (storeAccounts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('لا توجد حسابات لهذا المحل'),
                      ),
                    for (final account in storeAccounts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.badge_outlined),
                        ),
                        title: Text(
                          account.email,
                          textDirection: TextDirection.ltr,
                        ),
                        subtitle: const Text(
                          'كلمة المرور تظهر مرة واحدة عند الإنشاء.',
                        ),
                        trailing: Text('${account.deviceCount} جهاز'),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      );

  Future<void> _addAccount(BuildContext context, PartnerStore partner) async {
    final issued = await _showMerchantAccountEditor(context, cubit, partner);
    if (issued == null) return;
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تم إنشاء الحساب'),
        content: SelectableText(
            'البريد: ${issued.account.email}\nكلمة المرور المؤقتة: ${issued.temporaryPassword}',
            textDirection: TextDirection.ltr),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context), child: const Text('تم'))
        ],
      ),
    );
  }
}

class SettlementsAdmin extends StatelessWidget {
  const SettlementsAdmin({
    required this.cubit,
    required this.settlements,
    super.key,
  });

  final AdminAppCubit cubit;
  final List<MerchantSettlementSummary> settlements;

  @override
  Widget build(BuildContext context) => _AdminPage(children: [
        const _PageTitle(
            title: 'التحاسب الشهري',
            subtitle: 'إجمالي المبيعات والعمولة المستحقة لكل محل'),
        const SizedBox(height: 18),
        _TableCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('المحل')),
              DataColumn(label: Text('العمليات')),
              DataColumn(label: Text('المبيعات')),
              DataColumn(label: Text('العمولة')),
              DataColumn(label: Text('الحالة'))
            ],
            rows: settlements.map((settlement) {
              final transactions = settlement.transactionCount;
              final sales = settlement.totalSalesSyp;
              final commission = settlement.commissionDueSyp;
              final settled = settlement.status == 'settled';
              return DataRow(cells: [
                DataCell(Text(settlement.storeName,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
                DataCell(Text('$transactions')),
                DataCell(Text('${formatNumber(sales)} ل.س')),
                DataCell(Text('${formatNumber(commission)} ل.س')),
                DataCell(FilledButton.tonalIcon(
                    onPressed:
                        settled ? null : () => cubit.settleStore(settlement),
                    icon: Icon(settled
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded),
                    label: Text(settled ? 'تم التسديد' : 'تحديد كمسدد'))),
              ]);
            }).toList(),
          ),
        ),
      ]);
}

class SettingsAdmin extends StatefulWidget {
  const SettingsAdmin({
    required this.cubit,
    required this.pointValueSyp,
    super.key,
  });

  final AdminAppCubit cubit;
  final int? pointValueSyp;

  @override
  State<SettingsAdmin> createState() => _SettingsAdminState();
}

class _SettingsAdminState extends State<SettingsAdmin> {
  late final controller =
      TextEditingController(text: (widget.pointValueSyp ?? 1).toString());

  @override
  void didUpdateWidget(covariant SettingsAdmin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pointValueSyp != widget.pointValueSyp &&
        widget.pointValueSyp != null) {
      controller.text = widget.pointValueSyp.toString();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AdminPage(children: [
        const _PageTitle(
            title: 'الإعدادات العامة',
            subtitle: 'قيم مالية تؤثر في حسابات المنصة'),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'قيمة النقطة نقداً', suffixText: 'ل.س')),
                    const SizedBox(height: 10),
                    Text(
                        'تُستخدم هذه القيمة لحساب نقاط الفاتورة وقيمة طلب الاستبدال.',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 18),
                    FilledButton(
                        onPressed: _save, child: const Text('حفظ الإعدادات')),
                  ]),
            ),
          ),
        ),
      ]);

  Future<void> _save() async {
    final value = int.tryParse(controller.text) ?? 0;
    if (value <= 0) return;
    await widget.cubit.updatePointValue(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم حفظ قيمة النقطة.')));
  }
}

Customer _customerForRequest(
  CashRedemptionRequest request,
  List<Customer> customers,
) {
  for (final customer in customers) {
    if (customer.id == request.customerId) return customer;
  }
  return Customer(
    id: request.customerId,
    name: request.customerId,
    governorate: '',
    pointsBalance: 0,
    createdAt: request.createdAt,
  );
}

Future<PartnerStore?> _showStoreEditor(
  BuildContext context, [
  PartnerStore? partner,
]) async {
  final name = TextEditingController(text: partner?.name);
  final category = TextEditingController(text: partner?.category);
  final rate = TextEditingController(text: partner?.commissionRate.toString());
  final location = TextEditingController(text: partner?.location);
  final description = TextEditingController(text: partner?.description);
  try {
    return await showDialog<PartnerStore>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(partner == null ? 'إضافة محل' : 'تعديل المحل'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم المحل')),
              const SizedBox(height: 10),
              TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'الفئة')),
              const SizedBox(height: 10),
              TextField(
                  controller: rate,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'نسبة العمولة %')),
              const SizedBox(height: 10),
              TextField(
                  controller: location,
                  decoration: const InputDecoration(labelText: 'الموقع')),
              const SizedBox(height: 10),
              TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'الوصف')),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final now = DateTime.now().microsecondsSinceEpoch;
              Navigator.pop(
                context,
                PartnerStore(
                  id: partner?.id ?? 'store-$now',
                  name: name.text.trim(),
                  category: category.text.trim(),
                  commissionRate: double.tryParse(rate.text) ??
                      partner?.commissionRate ??
                      0,
                  description: description.text.trim(),
                  location: location.text.trim(),
                  iconSeed: partner?.iconSeed ?? now.remainder(100000),
                  isActive: partner?.isActive ?? true,
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  } finally {
    name.dispose();
    category.dispose();
    rate.dispose();
    location.dispose();
    description.dispose();
  }
}

Future<DigitalProduct?> _showProductEditor(
  BuildContext context, [
  DigitalProduct? product,
]) async {
  final name = TextEditingController(text: product?.name);
  final cost = TextEditingController(text: product?.costInPoints.toString());
  var needsPhone = product?.requiresPhoneNumber ?? false;
  var active = product?.isActive ?? true;
  try {
    return await showDialog<DigitalProduct>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(product == null ? 'إضافة منتج' : 'تعديل المنتج'),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم المنتج')),
              const SizedBox(height: 10),
              TextField(
                  controller: cost,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'التكلفة بالنقاط')),
              SwitchListTile(
                  value: needsPhone,
                  onChanged: (value) => setLocalState(() => needsPhone = value),
                  title: const Text('يتطلب رقم هاتف')),
              SwitchListTile(
                  value: active,
                  onChanged: (value) => setLocalState(() => active = value),
                  title: const Text('المنتج نشط')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final now = DateTime.now().microsecondsSinceEpoch;
                Navigator.pop(
                  context,
                  DigitalProduct(
                    id: product?.id ?? 'product-$now',
                    name: name.text.trim(),
                    costInPoints:
                        int.tryParse(cost.text) ?? product?.costInPoints ?? 0,
                    iconSeed: product?.iconSeed ?? now.remainder(100000),
                    requiresPhoneNumber: needsPhone,
                    isActive: active,
                  ),
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  } finally {
    name.dispose();
    cost.dispose();
  }
}

Future<IssuedMerchantAccount?> _showMerchantAccountEditor(
  BuildContext context,
  AdminAppCubit cubit,
  PartnerStore store,
) async {
  String email = '';
  String password = '';
  String label = store.name;

  final values = await showDialog<Map<String, String>>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('توليد حساب محل'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                ),
                onChanged: (value) => email = value,
              ),
              const SizedBox(height: 10),
              TextField(
                textDirection: TextDirection.ltr,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة مرور اختيارية',
                ),
                onChanged: (value) => password = value,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'اسم الجهاز',
                ),
                onChanged: (value) => label = value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop({
            'email': email.trim(),
            'password': password.trim(),
            'label': label.trim(),
          }),
          child: const Text('إنشاء'),
        ),
      ],
    ),
  );

  if (values == null) return null;

  final accountEmail = values['email']?.trim() ?? '';
  if (accountEmail.isEmpty) return null;

  final accountPassword = values['password']?.trim() ?? '';
  final displayLabel = values['label']?.trim() ?? '';

  return cubit.createMerchantAccount(
    storeId: store.id,
    email: accountEmail,
    password: accountPassword.isEmpty ? null : accountPassword,
    displayLabel: displayLabel.isEmpty ? null : displayLabel,
  );
}

class _AdminPage extends StatelessWidget {
  const _AdminPage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children)))
      ]);
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle, this.action});

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
              width: 520,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant))
                  ])),
          if (action != null) action!,
        ],
      );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: .14),
                foregroundColor: color,
                child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(label, style: Theme.of(context).textTheme.bodySmall)
                ]))
          ]),
        ),
      );
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal, child: child));
}

class _EmptyAdmin extends StatelessWidget {
  const _EmptyAdmin({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(children: [
            Icon(icon, size: 54, color: YallaColors.success),
            const SizedBox(height: 12),
            Text(text)
          ])));
}
