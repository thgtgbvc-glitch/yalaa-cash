import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yalla_cash_core/src/core/failure.dart';
import 'package:yalla_cash_core/src/domain/yalla_cash_repository.dart';
import 'package:yalla_cash_core/src/models.dart';

const _unset = Object();

class CustomerAppState extends Equatable {
  const CustomerAppState({
    this.status = LoadStatus.initial,
    this.session,
    this.customer,
    this.points,
    this.qrToken,
    this.stores = const [],
    this.transactions = const [],
    this.products = const [],
    this.cashRequests = const [],
    this.failure,
  });

  final LoadStatus status;
  final AuthSession? session;
  final Customer? customer;
  final PointsSummary? points;
  final CustomerQrToken? qrToken;
  final List<PartnerStore> stores;
  final List<LoyaltyTransaction> transactions;
  final List<DigitalProduct> products;
  final List<CashRedemptionRequest> cashRequests;
  final YallaCashFailure? failure;

  bool get isAuthenticated => session?.role == YallaUserRole.customer;

  CustomerAppState copyWith({
    LoadStatus? status,
    Object? session = _unset,
    Object? customer = _unset,
    Object? points = _unset,
    Object? qrToken = _unset,
    List<PartnerStore>? stores,
    List<LoyaltyTransaction>? transactions,
    List<DigitalProduct>? products,
    List<CashRedemptionRequest>? cashRequests,
    Object? failure = _unset,
  }) =>
      CustomerAppState(
        status: status ?? this.status,
        session:
            identical(session, _unset) ? this.session : session as AuthSession?,
        customer:
            identical(customer, _unset) ? this.customer : customer as Customer?,
        points:
            identical(points, _unset) ? this.points : points as PointsSummary?,
        qrToken: identical(qrToken, _unset)
            ? this.qrToken
            : qrToken as CustomerQrToken?,
        stores: stores ?? this.stores,
        transactions: transactions ?? this.transactions,
        products: products ?? this.products,
        cashRequests: cashRequests ?? this.cashRequests,
        failure: identical(failure, _unset)
            ? this.failure
            : failure as YallaCashFailure?,
      );

  @override
  List<Object?> get props => [
        status,
        session,
        customer,
        points,
        qrToken,
        stores,
        transactions,
        products,
        cashRequests,
        failure,
      ];
}

class CustomerAppCubit extends Cubit<CustomerAppState> {
  CustomerAppCubit(this._repository) : super(const CustomerAppState());

  final YallaCashRepository _repository;

  Future<void> restoreSession() async {
    try {
      emit(state.copyWith(status: LoadStatus.loading, failure: null));
      final results = await _loadCustomerData();
      emit(
        state.copyWith(
          status: LoadStatus.success,
          customer: results[0] as Customer,
          points: results[1] as PointsSummary,
          stores: results[2] as List<PartnerStore>,
          transactions: results[3] as List<LoyaltyTransaction>,
          products: results[4] as List<DigitalProduct>,
          cashRequests: results[5] as List<CashRedemptionRequest>,
          failure: null,
        ),
      );
    } on YallaCashFailure catch (failure) {
      if (failure.statusCode == 401 || failure.code == 'unauthorized') {
        emit(const CustomerAppState());
        return;
      }
      emit(state.copyWith(status: LoadStatus.failure, failure: failure));
    }
  }

  Future<PhoneOtpChallenge?> startPhoneOtp(String phone) async {
    try {
      emit(state.copyWith(status: LoadStatus.loading, failure: null));
      final challenge = await _repository.startCustomerPhoneOtp(phone);
      emit(state.copyWith(status: LoadStatus.success, failure: null));
      return challenge;
    } on YallaCashFailure catch (failure) {
      emit(state.copyWith(status: LoadStatus.failure, failure: failure));
      return null;
    }
  }

  Future<void> verifyPhoneOtp({
    required String challengeId,
    required String phone,
    required String code,
    required String name,
    required String governorate,
  }) async {
    await _run(() async {
      final session = await _repository.verifyCustomerPhoneOtp(
        challengeId: challengeId,
        phone: phone,
        code: code,
        name: name,
        governorate: governorate,
      );
      emit(state.copyWith(session: session, customer: session.customer));
      await refresh();
    });
  }

  Future<void> signInWithOAuth({
    required AuthMethod provider,
    required String firebaseIdToken,
    required String name,
    required String governorate,
  }) async {
    await _run(() async {
      final session = await _repository.signInCustomerWithOAuth(
        provider: provider,
        firebaseIdToken: firebaseIdToken,
        name: name,
        governorate: governorate,
      );
      emit(state.copyWith(session: session, customer: session.customer));
      await refresh();
    });
  }

  Future<void> refresh() async {
    await _run(() async {
      final results = await _loadCustomerData();
      emit(
        state.copyWith(
          status: LoadStatus.success,
          customer: results[0] as Customer,
          points: results[1] as PointsSummary,
          stores: results[2] as List<PartnerStore>,
          transactions: results[3] as List<LoyaltyTransaction>,
          products: results[4] as List<DigitalProduct>,
          cashRequests: results[5] as List<CashRedemptionRequest>,
          failure: null,
        ),
      );
    });
  }

  Future<void> updateGovernorate(String governorateId) async {
    await _run(() async {
      final customer =
          await _repository.updateCustomerGovernorate(governorateId);
      emit(state.copyWith(customer: customer, qrToken: null));
      await refresh();
    });
  }

  Future<void> issueQrToken() async {
    await _run(() async {
      final qr = await _repository.issueCustomerQrToken();
      emit(state.copyWith(qrToken: qr));
    });
  }

  Future<void> requestCashRedemption(int points) async {
    await _run(() async {
      await _repository.requestCashRedemption(points);
      await refresh();
    });
  }

  Future<void> redeemDigitalProduct(DigitalProduct product,
      {String? phoneNumber}) async {
    await _run(() async {
      await _repository.redeemDigitalProduct(
          product: product, phoneNumber: phoneNumber);
      await refresh();
    });
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const CustomerAppState());
  }

  Future<List<Object>> _loadCustomerData() => Future.wait<Object>([
        _repository.getCustomerProfile(),
        _repository.getCustomerPoints(),
        _repository.listActiveStores(),
        _repository.listCustomerTransactions(),
        _repository.listDigitalProducts(),
        _repository.listCustomerCashRequests(),
      ]);

  Future<void> _run(Future<void> Function() action) async {
    try {
      emit(state.copyWith(status: LoadStatus.loading, failure: null));
      await action();
      if (state.status == LoadStatus.loading) {
        emit(state.copyWith(status: LoadStatus.success, failure: null));
      }
    } on YallaCashFailure catch (failure) {
      emit(state.copyWith(status: LoadStatus.failure, failure: failure));
    }
  }
}

class MerchantAppState extends Equatable {
  const MerchantAppState({
    this.status = LoadStatus.initial,
    this.session,
    this.workspace,
    this.scannedCustomer,
    this.lastTransaction,
    this.failure,
  });

  final LoadStatus status;
  final AuthSession? session;
  final MerchantWorkspaceSnapshot? workspace;
  final Customer? scannedCustomer;
  final LoyaltyTransaction? lastTransaction;
  final YallaCashFailure? failure;

  bool get isAuthenticated => session?.role == YallaUserRole.merchant;

  MerchantAppState copyWith({
    LoadStatus? status,
    Object? session = _unset,
    Object? workspace = _unset,
    Object? scannedCustomer = _unset,
    Object? lastTransaction = _unset,
    Object? failure = _unset,
  }) =>
      MerchantAppState(
        status: status ?? this.status,
        session:
            identical(session, _unset) ? this.session : session as AuthSession?,
        workspace: identical(workspace, _unset)
            ? this.workspace
            : workspace as MerchantWorkspaceSnapshot?,
        scannedCustomer: identical(scannedCustomer, _unset)
            ? this.scannedCustomer
            : scannedCustomer as Customer?,
        lastTransaction: identical(lastTransaction, _unset)
            ? this.lastTransaction
            : lastTransaction as LoyaltyTransaction?,
        failure: identical(failure, _unset)
            ? this.failure
            : failure as YallaCashFailure?,
      );

  @override
  List<Object?> get props => [
        status,
        session,
        workspace,
        scannedCustomer,
        lastTransaction,
        failure,
      ];
}

class MerchantAppCubit extends Cubit<MerchantAppState> {
  MerchantAppCubit(this._repository) : super(const MerchantAppState());

  final YallaCashRepository _repository;

  Future<void> restoreSession() async {
    try {
      emit(state.copyWith(status: LoadStatus.loading, failure: null));
      final workspace = await _repository.getMerchantWorkspace();
      emit(
        state.copyWith(
          status: LoadStatus.success,
          workspace: workspace,
          failure: null,
        ),
      );
    } on YallaCashFailure catch (failure) {
      if (failure.statusCode == 401 || failure.code == 'unauthorized') {
        emit(const MerchantAppState());
        return;
      }
      emit(state.copyWith(status: LoadStatus.failure, failure: failure));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      emit(state.copyWith(
        status: LoadStatus.loading,
        failure: null,
      ));

      final session = await _repository.signInAdmin(
        email: email,
        password: password,
      );

      emit(state.copyWith(
        session: session,
        status: LoadStatus.success,
        failure: null,
      ));

      unawaited(refresh());
    } on YallaCashFailure catch (failure) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        failure: failure,
      ));
    }
  }

  Future<void> refresh() async {
    await _run(() async {
      final workspace = await _repository.getMerchantWorkspace();
      emit(state.copyWith(workspace: workspace, failure: null));
    });
  }

  Future<void> registerDevice(
      {required String fingerprint, required String label}) async {
    await _run(() => _repository.registerMerchantDevice(
        fingerprint: fingerprint, label: label));
  }

  Future<void> resolveQr(String payload) async {
    await _run(() async {
      final customer = await _repository.resolveCustomerQr(payload);
      emit(state.copyWith(scannedCustomer: customer, lastTransaction: null));
    });
  }

  Future<void> registerInvoice({
    required String customerQrPayload,
    required int amountSyp,
    required String idempotencyKey,
  }) async {
    await _run(() async {
      final transaction = await _repository.registerInvoice(
        customerQrPayload: customerQrPayload,
        amountSyp: amountSyp,
        idempotencyKey: idempotencyKey,
      );
      emit(state.copyWith(lastTransaction: transaction));
      await refresh();
    });
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const MerchantAppState());
  }

  void resetSaleFlow() {
    emit(
      state.copyWith(
        status:
            state.workspace == null ? LoadStatus.initial : LoadStatus.success,
        scannedCustomer: null,
        lastTransaction: null,
        failure: null,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      emit(state.copyWith(status: LoadStatus.loading, failure: null));
      await action();
      if (state.status == LoadStatus.loading) {
        emit(state.copyWith(status: LoadStatus.success, failure: null));
      }
    } on YallaCashFailure catch (failure) {
      emit(state.copyWith(status: LoadStatus.failure, failure: failure));
    }
  }
}

class AdminAppState extends Equatable {
  const AdminAppState({
    this.status = LoadStatus.initial,
    this.session,
    this.overview,
    this.customers = const [],
    this.stores = const [],
    this.products = const [],
    this.cashRequests = const [],
    this.merchantAccounts = const [],
    this.settlements = const [],
    this.pointValueSyp,
    this.failure,
  });

  final LoadStatus status;
  final AuthSession? session;
  final AdminOverviewSnapshot? overview;
  final List<Customer> customers;
  final List<PartnerStore> stores;
  final List<DigitalProduct> products;
  final List<CashRedemptionRequest> cashRequests;
  final List<MerchantAccount> merchantAccounts;
  final List<MerchantSettlementSummary> settlements;
  final int? pointValueSyp;
  final YallaCashFailure? failure;

  bool get isAuthenticated => session?.role == YallaUserRole.admin;

  AdminAppState copyWith({
    LoadStatus? status,
    Object? session = _unset,
    Object? overview = _unset,
    List<Customer>? customers,
    List<PartnerStore>? stores,
    List<DigitalProduct>? products,
    List<CashRedemptionRequest>? cashRequests,
    List<MerchantAccount>? merchantAccounts,
    List<MerchantSettlementSummary>? settlements,
    Object? pointValueSyp = _unset,
    Object? failure = _unset,
  }) =>
      AdminAppState(
        status: status ?? this.status,
        session:
            identical(session, _unset) ? this.session : session as AuthSession?,
        overview: identical(overview, _unset)
            ? this.overview
            : overview as AdminOverviewSnapshot?,
        customers: customers ?? this.customers,
        stores: stores ?? this.stores,
        products: products ?? this.products,
        cashRequests: cashRequests ?? this.cashRequests,
        merchantAccounts: merchantAccounts ?? this.merchantAccounts,
        settlements: settlements ?? this.settlements,
        pointValueSyp: identical(pointValueSyp, _unset)
            ? this.pointValueSyp
            : pointValueSyp as int?,
        failure: identical(failure, _unset)
            ? this.failure
            : failure as YallaCashFailure?,
      );

  @override
  List<Object?> get props => [
        status,
        session,
        overview,
        customers,
        stores,
        products,
        cashRequests,
        merchantAccounts,
        settlements,
        pointValueSyp,
        failure,
      ];
}

class AdminAppCubit extends Cubit<AdminAppState> {
  AdminAppCubit(this._repository) : super(const AdminAppState());

  final YallaCashRepository _repository;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _run(() async {
      final session =
          await _repository.signInAdmin(email: email, password: password);
      emit(state.copyWith(session: session));
      await refresh();
    });
  }

  Future<void> refresh() async {
    try {
      emit(state.copyWith(status: LoadStatus.loading, failure: null));

      final results = await Future.wait<Object>([
        _repository.getAdminOverview(),
        _repository.listAdminCustomers(),
        _repository.listAdminStores(),
        _repository.listAdminProducts(),
        _repository.listAdminCashRequests(status: 'pending'),
        _repository.listMerchantAccounts(),
        _repository.listSettlements(),
        _repository.getPointValue(),
      ]);

      emit(
        state.copyWith(
          status: LoadStatus.success,
          overview: results[0] as AdminOverviewSnapshot,
          customers: results[1] as List<Customer>,
          stores: results[2] as List<PartnerStore>,
          products: results[3] as List<DigitalProduct>,
          cashRequests: results[4] as List<CashRedemptionRequest>,
          merchantAccounts: results[5] as List<MerchantAccount>,
          settlements: results[6] as List<MerchantSettlementSummary>,
          pointValueSyp: results[7] as int,
          failure: null,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('ADMIN REFRESH ERROR: $error');
      debugPrint('$stackTrace');

      // Keep the current dashboard data instead of crashing the admin panel.
      emit(
        state.copyWith(
          status: LoadStatus.success,
        ),
      );
    }
  }

  Future<void> grantPoints(Customer customer, int points, String note) async {
    await _run(() async {
      await _repository.grantCustomerPoints(
        customerId: customer.id,
        points: points,
        note: note,
      );
      await refresh();
    });
  }

  Future<void> deductPoints(Customer customer, int points, String note) async {
    await _run(() async {
      await _repository.deductCustomerPoints(
        customerId: customer.id,
        points: points,
        note: note,
      );
      await refresh();
    });
  }

  Future<void> deleteCustomer(Customer customer) async {
    await _run(() async {
      await _repository.deleteCustomer(customer.id);
      await refresh();
    });
  }

  Future<void> resolveCashRequest(
      CashRedemptionRequest request, bool approve) async {
    await _run(() async {
      await _repository.resolveCashRequest(
          requestId: request.id, approve: approve);
      await refresh();
    });
  }

  Future<void> createStore(PartnerStore store) async {
    await _run(() async {
      await _repository.createStore(store);
      await refresh();
    });
  }

  Future<void> updateStore(PartnerStore store) async {
    await _run(() async {
      await _repository.updateStore(store);
      await refresh();
    });
  }

  Future<void> createProduct(DigitalProduct product) async {
    await _run(() async {
      await _repository.createProduct(product);
      await refresh();
    });
  }

  Future<void> updateProduct(DigitalProduct product) async {
    await _run(() async {
      await _repository.updateProduct(product);
      await refresh();
    });
  }

  Future<IssuedMerchantAccount?> createMerchantAccount({
    required String storeId,
    required String email,
    String? password,
    String? displayLabel,
  }) async {
    try {
      emit(state.copyWith(status: LoadStatus.loading, failure: null));
      final account = await _repository.createMerchantAccount(
        storeId: storeId,
        email: email,
        password: password,
        displayLabel: displayLabel,
      );
      await refresh();
      return account;
    } on YallaCashFailure catch (failure) {
      emit(state.copyWith(status: LoadStatus.failure, failure: failure));
      return null;
    }
  }

  Future<void> settleStore(MerchantSettlementSummary settlement) async {
    await _run(() async {
      await _repository.settleStore(
        storeId: settlement.storeId,
        periodStart: settlement.periodStart,
        periodEnd: settlement.periodEnd,
      );
      await refresh();
    });
  }

  Future<void> updatePointValue(int pointValueSyp) async {
    await _run(() async {
      final value = await _repository.updatePointValue(pointValueSyp);
      emit(state.copyWith(pointValueSyp: value));
      await refresh();
    });
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AdminAppState());
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      emit(state.copyWith(status: LoadStatus.loading, failure: null));
      await action();
      if (state.status == LoadStatus.loading) {
        emit(state.copyWith(status: LoadStatus.success, failure: null));
      }
    } on YallaCashFailure catch (failure) {
      emit(state.copyWith(status: LoadStatus.failure, failure: failure));
    }
  }
}
