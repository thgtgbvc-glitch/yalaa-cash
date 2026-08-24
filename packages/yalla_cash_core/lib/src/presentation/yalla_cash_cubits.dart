import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yalla_cash_core/src/core/failure.dart';
import 'package:yalla_cash_core/src/domain/yalla_cash_repository.dart';
import 'package:yalla_cash_core/src/models.dart';

const _unset = Object();

/// Builds a user-visible failure for exceptions that are not
/// [YallaCashFailure] (mapping bugs, unexpected runtime errors, ...).
///
/// These are logged and surfaced instead of being swallowed or crashing the
/// whole app.
YallaCashFailure _unexpectedFailure(Object error, StackTrace stackTrace) {
  debugPrint('YALLA CASH UNEXPECTED ERROR: $error');
  debugPrint('$stackTrace');
  return YallaCashFailure(
    code: 'unexpected_error',
    message: 'حدث خطأ غير متوقع. حاول مرة أخرى.',
    details: error,
  );
}

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
    this.banners = const [],
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

  /// Home-page banners. Owned by the Cubit (not local widget state) so that
  /// every refresh() reflects the latest admin-managed banners.
  final List<Banner> banners;
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
    List<Banner>? banners,
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
        banners: banners ?? this.banners,
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
        banners,
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
          banners: results[6] as List<Banner>,
          failure: null,
        ),
      );
    } on YallaCashFailure catch (failure) {
      if (failure.statusCode == 401 || failure.code == 'unauthorized') {
        // Invalid/expired session -> clean logout state (intentional).
        emit(const CustomerAppState());
        return;
      }
      emit(state.copyWith(status: LoadStatus.failure, failure: failure));
    } on Object catch (error, stackTrace) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        failure: _unexpectedFailure(error, stackTrace),
      ));
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
    } on Object catch (error, stackTrace) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        failure: _unexpectedFailure(error, stackTrace),
      ));
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
          banners: results[6] as List<Banner>,
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

  /// Loads every piece of customer data in parallel. Banners are included so
  /// a single refresh() always reflects the latest server state.
  Future<List<Object>> _loadCustomerData() => Future.wait<Object>([
        _repository.getCustomerProfile(),
        _repository.getCustomerPoints(),
        _repository.listActiveStores(),
        _repository.listCustomerTransactions(),
        _repository.listDigitalProducts(),
        _repository.listCustomerCashRequests(),
        _repository.listActiveBanners(placement: 'HOME'),
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
    } on Object catch (error, stackTrace) {
      // Surface unexpected errors visibly instead of crashing or hiding them.
      emit(state.copyWith(
        status: LoadStatus.failure,
        failure: _unexpectedFailure(error, stackTrace),
      ));
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
    } on Object catch (error, stackTrace) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        failure: _unexpectedFailure(error, stackTrace),
      ));
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

      // FIX: merchant accounts must authenticate through the MERCHANT login
      // endpoint (/auth/merchant/login). Calling signInAdmin here made the
      // backend filter by role=ADMIN, so valid merchant credentials were
      // always rejected with "Email or password is incorrect."
      final session = await _repository.signInMerchant(
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
    } on Object catch (error, stackTrace) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        failure: _unexpectedFailure(error, stackTrace),
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
    } on Object catch (error, stackTrace) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        failure: _unexpectedFailure(error, stackTrace),
      ));
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
    this.recentTransactions = const [],
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

  /// Latest loyalty transactions shown in the overview "recent activity"
  /// table. Previously this table rendered a hardcoded empty list.
  final List<LoyaltyTransaction> recentTransactions;
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
    List<LoyaltyTransaction>? recentTransactions,
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
        recentTransactions: recentTransactions ?? this.recentTransactions,
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
        recentTransactions,
        pointValueSyp,
        failure,
      ];
}

class AdminAppCubit extends Cubit<AdminAppState> {
  AdminAppCubit(this._repository) : super(const AdminAppState());

  final YallaCashRepository _repository;

  /// Monotonic refresh generation counter.
  ///
  /// Every refresh() call takes the next generation id; only the result of
  /// the LATEST generation may be emitted. Older concurrent refreshes are
  /// discarded when they finish late, so a stale snapshot can never
  /// overwrite newer state (e.g. resurrecting deleted rows or hiding new
  /// ones until an arbitrary later refresh).
  int _refreshGeneration = 0;

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
    final generation = ++_refreshGeneration;
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
        _repository.listAdminRecentTransactions(limit: 8),
      ]);

      // A newer refresh has started while this one was in flight: discard
      // this stale snapshot entirely.
      if (generation != _refreshGeneration) return;

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
          recentTransactions: results[8] as List<LoyaltyTransaction>,
          failure: null,
        ),
      );
    } on YallaCashFailure catch (failure) {
      if (generation != _refreshGeneration) return;
      // Keep the currently displayed data, but DO NOT fake success: the
      // failure is stored in state so the UI can surface it.
      emit(
        state.copyWith(
          status: LoadStatus.failure,
          failure: failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (generation != _refreshGeneration) return;
      emit(
        state.copyWith(
          status: LoadStatus.failure,
          failure: _unexpectedFailure(error, stackTrace),
        ),
      );
    }
  }

  Future<bool> grantPoints(Customer customer, int points, String note) =>
      _run(() async {
        await _repository.grantCustomerPoints(
          customerId: customer.id,
          points: points,
          note: note,
        );
        await refresh();
      });

  Future<bool> deductPoints(Customer customer, int points, String note) =>
      _run(() async {
        await _repository.deductCustomerPoints(
          customerId: customer.id,
          points: points,
          note: note,
        );
        await refresh();
      });

  Future<bool> deleteCustomer(Customer customer) => _run(() async {
        await _repository.deleteCustomer(customer.id);
        await refresh();
      });

  Future<bool> resolveCashRequest(
          CashRedemptionRequest request, bool approve) =>
      _run(() async {
        await _repository.resolveCashRequest(
            requestId: request.id, approve: approve);
        await refresh();
      });

  Future<bool> createStore(PartnerStore store) => _run(() async {
        await _repository.createStore(store);
        await refresh();
      });

  Future<bool> updateStore(PartnerStore store) => _run(() async {
        await _repository.updateStore(store);
        await refresh();
      });

  Future<bool> createProduct(DigitalProduct product) => _run(() async {
        await _repository.createProduct(product);
        await refresh();
      });

  Future<bool> updateProduct(DigitalProduct product) => _run(() async {
        await _repository.updateProduct(product);
        await refresh();
      });

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
    } on Object catch (error, stackTrace) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        failure: _unexpectedFailure(error, stackTrace),
      ));
      return null;
    }
  }

  Future<bool> settleStore(MerchantSettlementSummary settlement) =>
      _run(() async {
        await _repository.settleStore(
          storeId: settlement.storeId,
          periodStart: settlement.periodStart,
          periodEnd: settlement.periodEnd,
        );
        await refresh();
      });

  Future<bool> updatePointValue(int pointValueSyp) => _run(() async {
        final value = await _repository.updatePointValue(pointValueSyp);
        emit(state.copyWith(pointValueSyp: value));
        await refresh();
      });

  Future<void> logout() async {
    await _repository.logout();
    emit(const AdminAppState());
  }

  /// Runs [action], emitting loading/success/failure states.
  ///
  /// Returns true only when the whole action (including its trailing
  /// refresh) completed without failure, so callers can distinguish real
  /// success from silent failures.
  Future<bool> _run(Future<void> Function() action) async {
    try {
      emit(state.copyWith(status: LoadStatus.loading, failure: null));
      await action();
      if (state.status == LoadStatus.loading) {
        emit(state.copyWith(status: LoadStatus.success, failure: null));
      }
      return state.failure == null;
    } on YallaCashFailure catch (failure) {
      emit(state.copyWith(status: LoadStatus.failure, failure: failure));
      return false;
    } on Object catch (error, stackTrace) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        failure: _unexpectedFailure(error, stackTrace),
      ));
      return false;
    }
  }
}
