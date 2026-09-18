import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/config/env.dart';
import 'package:payflow/features/kyc/views/kyc_identity_screen.dart';
import 'package:payflow/features/kyc/views/kyc_personal_info_screen.dart';
import 'package:payflow/features/transfer/view_models/transfer_view_model.dart';
import 'package:payflow/features/wallet/view_models/wallet_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Env.setBackendApiBaseUrlForTesting(null);
  });

  tearDown(() {
    Env.setBackendApiBaseUrlForTesting(null);
  });

  group('Leak Prevention Tests — Live vs Mock Gating', () {
    test('1. Wallet transactions & balance: live mode is empty/honest, mock mode has sample data', () {
      // Live Mode
      Env.setBackendApiBaseUrlForTesting('https://api.payflow.app');
      expect(Env.isMockMode, isFalse);

      final liveWalletVm = WalletViewModel();
      expect(liveWalletVm.state.transactions, isEmpty);
      expect(liveWalletVm.state.mainBalance, equals(0.0));

      // Mock Mode
      Env.setBackendApiBaseUrlForTesting('');
      expect(Env.isMockMode, isTrue);

      final mockWalletVm = WalletViewModel();
      expect(mockWalletVm.state.transactions.length, equals(5));
      expect(mockWalletVm.state.mainBalance, equals(245850.75));
    });

    test('2. Transfer beneficiaries: live mode is empty, saveBeneficiary never saves fake contacts to SharedPreferences', () async {
      // Live Mode
      Env.setBackendApiBaseUrlForTesting('https://api.payflow.app');
      expect(Env.isMockMode, isFalse);

      final liveTransferVm = TransferViewModel();
      expect(liveTransferVm.state.recentBeneficiaries, isEmpty);

      // Save a real beneficiary in live mode
      const realBen = Beneficiary(
        id: 'real_123',
        name: 'Chukwuma Ugobueze',
        accountOrPhone: '08011112222',
        bankName: 'GTBank',
      );
      await liveTransferVm.saveBeneficiary(realBen);

      expect(liveTransferVm.state.recentBeneficiaries.length, equals(1));
      expect(liveTransferVm.state.recentBeneficiaries.first.name, equals('Chukwuma Ugobueze'));

      // Check SharedPreferences to verify fake contacts were NOT written
      final prefs = await SharedPreferences.getInstance();
      final savedRaw = prefs.getString('payflow_saved_beneficiaries');
      expect(savedRaw, isNotNull);
      final List<dynamic> savedList = jsonDecode(savedRaw!);
      expect(savedList.length, equals(1));
      expect(savedList.first['name'], equals('Chukwuma Ugobueze'));
      expect(savedList.any((b) => b['id'] == 'b1' || b['name'] == 'Sarah Connor'), isFalse);

      // Mock Mode
      Env.setBackendApiBaseUrlForTesting('');
      expect(Env.isMockMode, isTrue);

      final mockTransferVm = TransferViewModel();
      expect(mockTransferVm.state.recentBeneficiaries.length, equals(3));
      expect(mockTransferVm.state.recentBeneficiaries.any((b) => b.name == 'Sarah Connor'), isTrue);
    });

    testWidgets('3. KYC Identity Screen: live mode shows blank inputs with clean hints, mock mode shows sample data', (tester) async {
      // Live Mode
      Env.setBackendApiBaseUrlForTesting('https://api.payflow.app');
      expect(Env.isMockMode, isFalse);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: KycIdentityScreen(key: UniqueKey()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      final bvnWidget = tester.widget<TextFormField>(textFields.at(0));
      final ninWidget = tester.widget<TextFormField>(textFields.at(1));

      expect(bvnWidget.controller?.text, isEmpty);
      expect(ninWidget.controller?.text, isEmpty);

      // Mock Mode
      Env.setBackendApiBaseUrlForTesting('');
      expect(Env.isMockMode, isTrue);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: KycIdentityScreen(key: UniqueKey()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mockFields = find.byType(TextFormField);
      final mockBvn = tester.widget<TextFormField>(mockFields.at(0));
      final mockNin = tester.widget<TextFormField>(mockFields.at(1));

      expect(mockBvn.controller?.text, equals('22345678901'));
      expect(mockNin.controller?.text, equals('12345678901'));
    });

    testWidgets('4. KYC Personal Info Screen: live mode leaves DOB blank, mock mode shows sample DOB', (tester) async {
      // Live Mode
      Env.setBackendApiBaseUrlForTesting('https://api.payflow.app');
      expect(Env.isMockMode, isFalse);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: KycPersonalInfoScreen(key: UniqueKey()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1995-06-15'), findsNothing);

      // Mock Mode
      Env.setBackendApiBaseUrlForTesting('');
      expect(Env.isMockMode, isTrue);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: KycPersonalInfoScreen(key: UniqueKey()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mockDobField = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == '1995-06-15',
      );
      expect(mockDobField, findsOneWidget);
    });
  });
}
