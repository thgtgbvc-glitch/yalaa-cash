import 'package:yalla_cash_core/src/data/yalla_cash_api_client.dart';
import 'package:yalla_cash_core/src/domain/yalla_cash_repository.dart';
import 'package:yalla_cash_core/src/models.dart';

class RemoteYallaCashRepository implements YallaCashRepository {
  RemoteYallaCashRepository(this._client);

  final YallaCashApiClient _client;

  @override
  Future<PhoneOtpChallenge> startCustomerPhoneOtp(String phone) async {
    final json = apiMap(
      await _client.post(
        '/auth/customer/phone/start',
        body: {'phone': phone},
        authenticated: false,
      ),
    );
    return PhoneOtpChallenge(
      challengeId: json['challengeId']! as String,
      expiresInSeconds: json['expiresInSeconds']! as int,
      devCode: json['devCode'] as String?,
    );
  }

  @override
  Future<AuthSession> verifyCustomerPhoneOtp({
    required String challengeId,
    required String phone,
    required String code,
    required String name,
    required String governorate,
  }) =>
      _authenticate(
        '/auth/customer/phone/verify',
        {
          'challengeId': challengeId,
          'phone': phone,
          'code': code,
          'name': name,
          'governorate': governorate,
        },
      );

  @override
  Future<AuthSession> signInCustomerWithOAuth({
    required AuthMethod provider,
    required String firebaseIdToken,
    required String name,
    required String governorate,
  }) =>
      _authenticate(
        '/auth/customer/oauth',
        {
          'provider': provider == AuthMethod.gmail ? 'GOOGLE' : 'FACEBOOK',
          'firebaseIdToken': firebaseIdToken,
          'name': name,
          'governorate': governorate,
        },
      );

  @override
  Future<AuthSession> signInMerchant({
    required String email,
    required String password,
  }) =>
      _authenticate(
        '/auth/merchant/login',
        {'email': email, 'password': password},
      );

  @override
  Future<AuthSession> signInAdmin({
    required String email,
    required String password,
  }) =>
      _authenticate(
        '/auth/admin/login',
        {'email': email, 'password': password},
      );

  @override
  Future<void> logout() async {
    final tokens = await _client.tokens;
    try {
      if (tokens != null) {
        await _client
            .post('/auth/logout', body: {'refreshToken': tokens.refreshToken});
      }
    } finally {
      await _client.clearTokens();
    }
  }

  @override
  Future<Customer> getCustomerProfile() async =>
      _customerFromApi(apiMap(await _client.get('/customer/profile')));

  @override
  Future<Customer> updateCustomerProfile({
    required String name,
    required String governorate,
    String? phone,
  }) async =>
      _customerFromApi(
        apiMap(
          await _client.patch(
            '/customer/profile',
            body: {
              'name': name,
              'governorate': governorate,
              if (phone != null) 'phone': phone,
            },
          ),
        ),
      );

  @override
  Future<List<Governorate>> listActiveGovernorates() async =>
      apiItems(await _client.get('/customer/governorates'))
          .map(_governorateFromApi)
          .toList(growable: false);

  @override
  Future<Customer> updateCustomerGovernorate(String governorateId) async =>
      _customerFromApi(
        apiMap(
          await _client.patch(
            '/customer/governorate',
            body: {'governorateId': governorateId},
          ),
        ),
      );

  @override
  Future<List<Banner>> listActiveBanners(
          {String? placement, String? governorateId}) async =>
      apiItems(await _client.get('/customer/banners',
              query: {'placement': placement ?? 'HOME'}))
          .map(_bannerFromApi)
          .where((banner) =>
              governorateId == null ||
              banner.governorateId == null ||
              banner.governorateId == governorateId)
          .toList(growable: false);

  @override
  Future<PointsSummary> getCustomerPoints() async {
    final json = apiMap(await _client.get('/customer/points'));
    return PointsSummary(
      pointsBalance: _int(json['pointsBalance']),
      heldPoints: _int(json['heldPoints']),
      availablePoints: _int(json['availablePoints']),
    );
  }

  @override
  Future<CustomerQrToken> issueCustomerQrToken() async {
    final json = apiMap(await _client.post('/customer/qr-token'));
    return CustomerQrToken(
      token: json['token']! as String,
      payload: json['payload']! as String,
      expiresAt: DateTime.parse(json['expiresAt']! as String),
    );
  }

  @override
  Future<List<PartnerStore>> listActiveStores(
          {String? city, String? category}) async =>
      apiItems(
        await _client.get(
          '/stores',
          query: {'city': city, 'category': category},
          authenticated: false,
        ),
      ).map(_storeFromApi).toList(growable: false);

  @override
  Future<List<LoyaltyTransaction>> listCustomerTransactions(
          {String? cursor}) async =>
      apiItems(
        await _client.get(
          '/customer/transactions',
          query: {'cursor': cursor},
        ),
      ).map(_transactionFromApi).toList(growable: false);

  @override
  Future<List<DigitalProduct>> listDigitalProducts() async =>
      apiItems(await _client.get('/customer/digital-products'))
          .map(_productFromApi)
          .toList(growable: false);

  @override
  Future<List<CashRedemptionRequest>> listCustomerCashRequests() async =>
      apiItems(await _client.get('/customer/redemptions/cash'))
          .map(_cashRequestFromApi)
          .toList(growable: false);

  @override
  Future<CashRedemptionRequest> requestCashRedemption(int points) async =>
      _cashRequestFromApi(
        apiMap(
          await _client.post(
            '/customer/redemptions/cash',
            body: {'points': points},
          ),
        ),
      );

  @override
  Future<void> redeemDigitalProduct({
    required DigitalProduct product,
    String? phoneNumber,
  }) async {
    await _client.post(
      '/customer/redemptions/products',
      body: {
        'productId': product.id,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      },
    );
  }

  @override
  Future<MerchantWorkspaceSnapshot> getMerchantWorkspace() async {
    final json = apiMap(await _client.get('/merchant/me'));
    return MerchantWorkspaceSnapshot(
      account: _merchantAccountFromApi(apiMap(json['account'])),
      store: _storeFromApi(apiMap(json['store'])),
      summary: _merchantSummaryFromApi(apiMap(json['summary'])),
      recentTransactions: (json['recentTransactions'] as List? ?? const [])
          .map((item) => _transactionFromApi(apiMap(item)))
          .toList(growable: false),
    );
  }

  @override
  Future<void> registerMerchantDevice({
    required String fingerprint,
    required String label,
  }) async {
    await _client.post(
      '/merchant/devices',
      body: {'fingerprint': fingerprint, 'label': label},
    );
  }

  @override
  Future<Customer> resolveCustomerQr(String payload) async => _customerFromApi(
        apiMap(
          await _client
              .post('/merchant/qr/resolve', body: {'payload': payload}),
        ),
      );

  @override
  Future<LoyaltyTransaction> registerInvoice({
    required String customerQrPayload,
    required int amountSyp,
    required String idempotencyKey,
  }) async =>
      _transactionFromApi(
        apiMap(
          await _client.post(
            '/merchant/invoices',
            body: {
              'customerQrPayload': customerQrPayload,
              'amountSyp': amountSyp,
              'idempotencyKey': idempotencyKey,
            },
          ),
        ),
      );

  @override
  Future<MerchantSummary> getMerchantSummary(
          {DateTime? from, DateTime? to}) async =>
      _merchantSummaryFromApi(
        apiMap(
          await _client.get(
            '/merchant/summary',
            query: {
              'from': from?.toIso8601String(),
              'to': to?.toIso8601String(),
            },
          ),
        ),
      );

  @override
  Future<List<LoyaltyTransaction>> listMerchantTransactions(
          {String? cursor}) async =>
      apiItems(
        await _client.get('/merchant/transactions', query: {'cursor': cursor}),
      ).map(_transactionFromApi).toList(growable: false);

  @override
  Future<AdminOverviewSnapshot> getAdminOverview() async {
    final json = apiMap(await _client.get('/admin/overview'));
    return AdminOverviewSnapshot(
      customers: _int(json['customers']),
      activeStores: _int(json['activeStores']),
      transactions: _int(json['transactions']),
      totalSalesSyp: _int(json['totalSalesSyp']),
      platformRevenueSyp: _int(json['platformRevenueSyp']),
      commissionDueSyp: _int(json['commissionDueSyp']),
      pendingCashRequests: _int(json['pendingCashRequests']),
    );
  }

  @override
  Future<List<Customer>> listAdminCustomers() async =>
      apiItems(await _client.get('/admin/customers'))
          .map(_customerFromApi)
          .toList(growable: false);

  @override
  Future<List<Governorate>> listAdminGovernorates() async =>
      apiItems(await _client.get('/admin/governorates'))
          .map(_governorateFromApi)
          .toList(growable: false);

  @override
  Future<List<Banner>> listAdminBanners({String? placement}) async => apiItems(
          await _client.get('/admin/banners', query: {'placement': placement}))
      .map(_bannerFromApi)
      .toList(growable: false);

  @override
  Future<Banner> createBanner(Banner banner) async => _bannerFromApi(
        apiMap(
          await _client.post(
            '/admin/banners',
            body: {
              'title': banner.title,
              'subtitle': banner.subtitle,
              'imageUrl': banner.imageUrl,
              'targetUrl': banner.targetUrl,
              'placement': _enumToApi(banner.placement),
              'style': _enumToApi(banner.style),
              'isActive': banner.isActive,
              'displayOrder': banner.displayOrder,
              'startsAt': banner.startsAt?.toIso8601String(),
              'endsAt': banner.endsAt?.toIso8601String(),
              'governorateId': banner.governorateId,
            },
          ),
        ),
      );

  @override
  Future<Banner> updateBanner(Banner banner) async => _bannerFromApi(
        apiMap(
          await _client.patch(
            '/admin/banners/${banner.id}',
            body: {
              'title': banner.title,
              'subtitle': banner.subtitle,
              'imageUrl': banner.imageUrl,
              'targetUrl': banner.targetUrl,
              'placement': _enumToApi(banner.placement),
              'style': _enumToApi(banner.style),
              'isActive': banner.isActive,
              'displayOrder': banner.displayOrder,
              'startsAt': banner.startsAt?.toIso8601String(),
              'endsAt': banner.endsAt?.toIso8601String(),
              'governorateId': banner.governorateId,
            },
          ),
        ),
      );

  @override
  Future<Governorate> createGovernorate(Governorate governorate) async =>
      _governorateFromApi(
        apiMap(
          await _client.post(
            '/admin/governorates',
            body: {
              'nameAr': governorate.nameAr,
              'isActive': governorate.isActive,
              'displayOrder': governorate.displayOrder,
            },
          ),
        ),
      );

  @override
  Future<Governorate> updateGovernorate(Governorate governorate) async =>
      _governorateFromApi(
        apiMap(
          await _client.patch(
            '/admin/governorates/${governorate.id}',
            body: {
              'nameAr': governorate.nameAr,
              'isActive': governorate.isActive,
              'displayOrder': governorate.displayOrder,
            },
          ),
        ),
      );

  @override
  Future<Customer> grantCustomerPoints({
    required String customerId,
    required int points,
    required String note,
  }) async =>
      _customerFromApi(
        apiMap(
          await _client.post(
            '/admin/customers/$customerId/points/grant',
            body: {'points': points, 'note': note},
          ),
        ),
      );

  @override
  Future<Customer> deductCustomerPoints({
    required String customerId,
    required int points,
    required String note,
  }) async =>
      _customerFromApi(
        apiMap(
          await _client.post(
            '/admin/customers/$customerId/points/deduct',
            body: {'points': points, 'note': note},
          ),
        ),
      );

  @override
  Future<void> deleteCustomer(String customerId) async {
    await _client.delete('/admin/customers/$customerId');
  }

  @override
  Future<List<CashRedemptionRequest>> listAdminCashRequests(
          {String? status}) async =>
      apiItems(
        await _client.get('/admin/cash-requests', query: {'status': status}),
      ).map(_cashRequestFromApi).toList(growable: false);

  @override
  Future<CashRedemptionRequest> resolveCashRequest({
    required String requestId,
    required bool approve,
  }) async =>
      _cashRequestFromApi(
        apiMap(
          await _client.post(
            '/admin/cash-requests/$requestId/resolve',
            body: {'approve': approve},
          ),
        ),
      );

  @override
  Future<List<PartnerStore>> listAdminStores() async =>
      apiItems(await _client.get('/admin/stores'))
          .map(_storeFromApi)
          .toList(growable: false);

  @override
  Future<PartnerStore> createStore(PartnerStore store) async => _storeFromApi(
      apiMap(await _client.post('/admin/stores', body: _storeToApi(store))));

  @override
  Future<PartnerStore> updateStore(PartnerStore store) async =>
      _storeFromApi(apiMap(await _client.patch('/admin/stores/${store.id}',
          body: _storeToApi(store))));

  @override
  Future<List<DigitalProduct>> listAdminProducts() async =>
      apiItems(await _client.get('/admin/products'))
          .map(_productFromApi)
          .toList(growable: false);

  @override
  Future<DigitalProduct> createProduct(DigitalProduct product) async =>
      _productFromApi(apiMap(
          await _client.post('/admin/products', body: _productToApi(product))));

  @override
  Future<DigitalProduct> updateProduct(DigitalProduct product) async =>
      _productFromApi(apiMap(await _client.patch(
          '/admin/products/${product.id}',
          body: _productToApi(product))));

  @override
  Future<List<MerchantAccount>> listMerchantAccounts() async =>
      apiItems(await _client.get('/admin/merchant-accounts'))
          .map(_merchantAccountFromApi)
          .toList(growable: false);

  @override
  Future<IssuedMerchantAccount> createMerchantAccount({
    required String storeId,
    required String email,
    String? password,
    String? displayLabel,
  }) async {
    final json = apiMap(
      await _client.post(
        '/admin/merchant-accounts',
        body: {
          'storeId': storeId,
          'email': email,
          if (password != null) 'password': password,
          if (displayLabel != null) 'displayLabel': displayLabel,
        },
      ),
    );
    return IssuedMerchantAccount(
      account: _merchantAccountFromApi(apiMap(json['account'])),
      temporaryPassword: json['temporaryPassword']! as String,
    );
  }

  @override
  Future<int> getPointValue() async =>
      _int(apiMap(await _client.get('/admin/settings'))['pointValueSyp']);

  @override
  Future<int> updatePointValue(int pointValueSyp) async => _int(
        apiMap(
          await _client.patch(
            '/admin/settings',
            body: {'pointValueSyp': pointValueSyp},
          ),
        )['pointValueSyp'],
      );

  @override
  Future<List<MerchantSettlementSummary>> listSettlements({
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async =>
      apiItems(
        await _client.get(
          '/admin/settlements',
          query: {
            'periodStart': periodStart?.toIso8601String(),
            'periodEnd': periodEnd?.toIso8601String(),
          },
        ),
      ).map(_settlementFromApi).toList(growable: false);

  @override
  Future<MerchantSettlementSummary> settleStore({
    required String storeId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async =>
      _settlementFromApi(
        apiMap(
          await _client.post(
            '/admin/settlements/settle',
            body: {
              'storeId': storeId,
              'periodStart': periodStart.toIso8601String(),
              'periodEnd': periodEnd.toIso8601String(),
            },
          ),
        ),
      );

  Future<AuthSession> _authenticate(
      String path, Map<String, Object?> body) async {
    final json =
        apiMap(await _client.post(path, body: body, authenticated: false));
    final tokens = authTokensFromResponse(json);
    await _client.saveTokens(tokens);
    final user = apiMap(json['user']);
    return AuthSession(
      userId: user['id']! as String,
      role: _roleFromApi(user['role']! as String),
      tokens: tokens,
      customer: json['profile'] == null
          ? null
          : _customerFromApi(apiMap(json['profile'])),
    );
  }

  Customer _customerFromApi(Map<String, Object?> json) => Customer(
        id: json['id']! as String,
        name: json['name']! as String,
        phone: json['phone'] as String?,
        authMethod: _authMethodFromApi(json['authMethod'] as String?),
        governorate: json['governorate']! as String,
        governorateId: json['governorateId'] as String?,
        pointsBalance: _int(json['pointsBalance']),
        createdAt: DateTime.parse(json['createdAt']! as String),
      );

  Governorate _governorateFromApi(Map<String, Object?> json) => Governorate(
        id: json['id']! as String,
        nameAr: json['nameAr']! as String,
        isActive: json['isActive'] as bool? ?? false,
        displayOrder: _int(json['displayOrder']),
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
      );

  Banner _bannerFromApi(Map<String, Object?> json) => Banner(
        id: json['id']! as String,
        title: json['title']! as String,
        subtitle: json['subtitle'] as String?,
        imageUrl: json['imageUrl']! as String,
        targetUrl: json['targetUrl'] as String?,
        placement: (json['placement'] as String?) ?? 'home',
        style: (json['style'] as String?) ?? 'promo',
        isActive: json['isActive'] as bool? ?? true,
        displayOrder: _int(json['displayOrder'] ?? 0),
        governorateId: json['governorateId'] as String?,
        startsAt: json['startsAt'] == null
            ? null
            : DateTime.parse(json['startsAt']! as String),
        endsAt: json['endsAt'] == null
            ? null
            : DateTime.parse(json['endsAt']! as String),
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
      );

  PartnerStore _storeFromApi(Map<String, Object?> json) => PartnerStore(
        id: json['id']! as String,
        name: json['name']! as String,
        category: json['category']! as String,
        commissionRate: _double(json['commissionRate']),
        description: (json['description'] as String?) ?? '',
        location:
            (json['location'] as String?) ?? (json['city'] as String?) ?? '',
        iconSeed: _int(json['iconSeed'] ?? 0),
        isActive: json['isActive'] as bool? ?? true,
      );

  LoyaltyTransaction _transactionFromApi(Map<String, Object?> json) =>
      LoyaltyTransaction(
        id: json['id']! as String,
        storeId: json['storeId']! as String,
        storeName: (json['storeName'] as String?) ?? '',
        customerId: json['customerId']! as String,
        amountSyp: _int(json['amountSyp']),
        commissionRateSnapshot: _double(json['commissionRateSnapshot']),
        commissionAmountSyp: _int(json['commissionAmountSyp']),
        platformRevenueSyp: _int(json['platformRevenueSyp']),
        customerShareSyp: _int(json['customerShareSyp']),
        customerPointsEarned: _int(json['customerPointsEarned']),
        createdAt: DateTime.parse(json['createdAt']! as String),
      );

  DigitalProduct _productFromApi(Map<String, Object?> json) => DigitalProduct(
        id: json['id']! as String,
        name: json['name']! as String,
        costInPoints: _int(json['costInPoints']),
        iconSeed: _int(json['iconSeed'] ?? 0),
        requiresPhoneNumber: json['requiresPhoneNumber'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
      );

  CashRedemptionRequest _cashRequestFromApi(Map<String, Object?> json) =>
      CashRedemptionRequest(
        id: json['id']! as String,
        customerId: json['customerId']! as String,
        pointsRequested: _int(json['pointsRequested']),
        cashValueSyp: _int(json['cashValueSyp']),
        status: _cashStatusFromApi(json['status']! as String),
        createdAt: DateTime.parse(json['createdAt']! as String),
        settledAt: json['settledAt'] == null
            ? null
            : DateTime.parse(json['settledAt']! as String),
      );

  MerchantAccount _merchantAccountFromApi(Map<String, Object?> json) =>
      MerchantAccount(
        id: json['id']! as String,
        storeId: json['storeId']! as String,
        email: (json['email'] as String?) ?? '',
        demoPassword: '',
        deviceCount: _int(json['deviceCount'] ?? 0),
      );

  MerchantSummary _merchantSummaryFromApi(Map<String, Object?> json) =>
      MerchantSummary(
        storeId: json['storeId']! as String,
        from: DateTime.parse(json['from']! as String),
        to: DateTime.parse(json['to']! as String),
        transactionCount: _int(json['transactionCount']),
        totalSalesSyp: _int(json['totalSalesSyp']),
        commissionDueSyp: _int(json['commissionDueSyp']),
      );

  MerchantSettlementSummary _settlementFromApi(Map<String, Object?> json) =>
      MerchantSettlementSummary(
        id: json['id'] as String?,
        storeId: json['storeId']! as String,
        storeName: json['storeName']! as String,
        periodStart: DateTime.parse(json['periodStart']! as String),
        periodEnd: DateTime.parse(json['periodEnd']! as String),
        transactionCount: _int(json['transactionCount']),
        totalSalesSyp: _int(json['totalSalesSyp']),
        commissionDueSyp: _int(json['commissionDueSyp']),
        status: json['status']! as String,
        settledAt: json['settledAt'] == null
            ? null
            : DateTime.parse(json['settledAt']! as String),
      );

  Map<String, Object?> _storeToApi(PartnerStore store) => {
        'name': store.name,
        'category': store.category,
        'city': _cityFromLocation(store.location),
        'commissionRate': store.commissionRate,
        'description': store.description,
        'location': store.location,
        'iconSeed': store.iconSeed,
        'isActive': store.isActive,
      };

  Map<String, Object?> _productToApi(DigitalProduct product) => {
        'name': product.name,
        'costInPoints': product.costInPoints,
        'iconSeed': product.iconSeed,
        'requiresPhoneNumber': product.requiresPhoneNumber,
        'isActive': product.isActive,
      };

  String _cityFromLocation(String location) {
    final parts = location.split(RegExp(r'\s*-\s*'));
    return parts.first.trim().isEmpty ? 'دمشق' : parts.first.trim();
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.parse(value.toString());
  }

  double _double(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.parse(value.toString());
  }

  String _enumToApi(String value) =>
      value.trim().replaceAll('-', '_').toUpperCase();

  AuthMethod _authMethodFromApi(String? value) {
    switch (value?.toLowerCase()) {
      case 'facebook':
        return AuthMethod.facebook;
      case 'google':
      case 'gmail':
        return AuthMethod.gmail;
      case 'phone':
      default:
        return AuthMethod.phone;
    }
  }

  CashRequestStatus _cashStatusFromApi(String value) {
    switch (value.toLowerCase()) {
      case 'settled':
        return CashRequestStatus.settled;
      case 'rejected':
        return CashRequestStatus.rejected;
      case 'pending':
      default:
        return CashRequestStatus.pending;
    }
  }

  YallaUserRole _roleFromApi(String value) {
    switch (value.toLowerCase()) {
      case 'merchant':
        return YallaUserRole.merchant;
      case 'admin':
        return YallaUserRole.admin;
      case 'customer':
      default:
        return YallaUserRole.customer;
    }
  }
}
