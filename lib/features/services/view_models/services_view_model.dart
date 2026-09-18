import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../transfer/view_models/transfer_view_model.dart';

class ServiceCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const ServiceCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class DataPlan {
  final String id;
  final String name;
  final String validity;
  final double price;
  final String? variationCode;

  const DataPlan({
    required this.id,
    required this.name,
    required this.validity,
    required this.price,
    this.variationCode,
  });

  factory DataPlan.fromVtpassJson(Map<String, dynamic> json) {
    final amountStr = json['variation_amount']?.toString() ?? '0';
    final amount = double.tryParse(amountStr) ?? 0.0;
    return DataPlan(
      id: json['variation_code']?.toString() ?? 'dp_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? 'Data Plan',
      validity: json['validity']?.toString() ?? '30 Days',
      price: amount,
      variationCode: json['variation_code']?.toString(),
    );
  }
}

class CablePackage {
  final String id;
  final String provider;
  final String packageName;
  final double price;

  const CablePackage({
    required this.id,
    required this.provider,
    required this.packageName,
    required this.price,
  });
}

class ServicesState {
  final List<ServiceCategory> categories;
  final List<String> networks;
  final List<DataPlan> dataPlans;
  final bool isLoadingDataPlans;
  final String? dataPlansError;
  final String currentNetwork;
  final List<String> electricityDiscos;
  final List<String> meterTypes;
  final List<String> cableProviders;
  final Map<String, List<CablePackage>> cablePackages;
  final List<Beneficiary> savedBillers;

  const ServicesState({
    required this.categories,
    required this.networks,
    required this.dataPlans,
    this.isLoadingDataPlans = false,
    this.dataPlansError,
    this.currentNetwork = 'mtn',
    required this.electricityDiscos,
    required this.meterTypes,
    required this.cableProviders,
    required this.cablePackages,
    this.savedBillers = const [],
  });

  ServicesState copyWith({
    List<ServiceCategory>? categories,
    List<String>? networks,
    List<DataPlan>? dataPlans,
    bool? isLoadingDataPlans,
    String? dataPlansError,
    String? currentNetwork,
    List<String>? electricityDiscos,
    List<String>? meterTypes,
    List<String>? cableProviders,
    Map<String, List<CablePackage>>? cablePackages,
    List<Beneficiary>? savedBillers,
  }) {
    return ServicesState(
      categories: categories ?? this.categories,
      networks: networks ?? this.networks,
      dataPlans: dataPlans ?? this.dataPlans,
      isLoadingDataPlans: isLoadingDataPlans ?? this.isLoadingDataPlans,
      dataPlansError: dataPlansError,
      currentNetwork: currentNetwork ?? this.currentNetwork,
      electricityDiscos: electricityDiscos ?? this.electricityDiscos,
      meterTypes: meterTypes ?? this.meterTypes,
      cableProviders: cableProviders ?? this.cableProviders,
      cablePackages: cablePackages ?? this.cablePackages,
      savedBillers: savedBillers ?? this.savedBillers,
    );
  }
}

class ServicesViewModel extends StateNotifier<ServicesState> {
  ServicesViewModel()
      : super(
          ServicesState(
            savedBillers: Env.isMockMode
                ? const [
                    Beneficiary(
                      id: 'b_elec_1',
                      name: 'IKEDC (Home)',
                      accountOrPhone: '0192837465',
                      bankName: 'Electricity',
                      category: 'bills',
                      serviceId: 'ikeja-electric',
                    ),
                    Beneficiary(
                      id: 'b_cable_1',
                      name: 'DSTV Compact',
                      accountOrPhone: '1029384756',
                      bankName: 'Cable TV',
                      category: 'bills',
                      serviceId: 'dstv',
                    ),
                    Beneficiary(
                      id: 'b_airtime_1',
                      name: 'MTN Airtime',
                      accountOrPhone: '08146357043',
                      bankName: 'Airtime',
                      category: 'airtime',
                      serviceId: 'mtn',
                    ),
                  ]
                : const [],
            categories: [
              ServiceCategory(
                id: 'airtime',
                title: 'Airtime',
                description: 'Instant mobile recharge',
                icon: Icons.phone_android_rounded,
                color: Color(0xFF3B82F6),
              ),
              ServiceCategory(
                id: 'data',
                title: 'Mobile Data',
                description: 'Internet bundles & plans',
                icon: Icons.wifi_rounded,
                color: Color(0xFF10B981),
              ),
              ServiceCategory(
                id: 'electricity',
                title: 'Electricity',
                description: 'Prepaid & Postpaid meters',
                icon: Icons.bolt_rounded,
                color: Color(0xFFF59E0B),
              ),
              ServiceCategory(
                id: 'cable',
                title: 'Cable TV',
                description: 'DSTV, GOtv & Startimes',
                icon: Icons.tv_rounded,
                color: Color(0xFF8B5CF6),
              ),
            ],
            networks: ['MTN', 'Airtel', 'Glo', '9mobile'],
            dataPlans: [
              DataPlan(id: 'dp_1', name: '500MB Data Plan', validity: '1 Day', price: 300.00),
              DataPlan(id: 'dp_2', name: '1.5GB Data Plan', validity: '30 Days', price: 1000.00),
              DataPlan(id: 'dp_3', name: '3GB Data Plan', validity: '30 Days', price: 1500.00),
              DataPlan(id: 'dp_4', name: '5GB Data Plan', validity: '30 Days', price: 2500.00),
              DataPlan(id: 'dp_5', name: '10GB Data Plan', validity: '30 Days', price: 5000.00),
              DataPlan(id: 'dp_6', name: '20GB Data Plan', validity: '30 Days', price: 9000.00),
            ],
            electricityDiscos: [
              'Ikeja Electric',
              'Eko Electricity',
              'Abuja Electricity',
              'Enugu Electricity',
              'Kano Electricity',
            ],
            meterTypes: ['Prepaid', 'Postpaid'],
            cableProviders: ['DSTV', 'GOtv', 'Startimes'],
            cablePackages: {
              'DSTV': [
                CablePackage(id: 'd_1', provider: 'DSTV', packageName: 'DSTV Yanga', price: 4200.00),
                CablePackage(id: 'd_2', provider: 'DSTV', packageName: 'DSTV Confam', price: 7400.00),
                CablePackage(id: 'd_3', provider: 'DSTV', packageName: 'DSTV Compact', price: 12500.00),
                CablePackage(id: 'd_4', provider: 'DSTV', packageName: 'DSTV Premium', price: 29500.00),
              ],
              'GOtv': [
                CablePackage(id: 'g_1', provider: 'GOtv', packageName: 'GOtv Smallie', price: 1300.00),
                CablePackage(id: 'g_2', provider: 'GOtv', packageName: 'GOtv Jinja', price: 2700.00),
                CablePackage(id: 'g_3', provider: 'GOtv', packageName: 'GOtv Jolli', price: 3950.00),
                CablePackage(id: 'g_4', provider: 'GOtv', packageName: 'GOtv Max', price: 5700.00),
              ],
              'Startimes': [
                CablePackage(id: 's_1', provider: 'Startimes', packageName: 'Startimes Nova', price: 1500.00),
                CablePackage(id: 's_2', provider: 'Startimes', packageName: 'Startimes Basic', price: 2600.00),
                CablePackage(id: 's_3', provider: 'Startimes', packageName: 'Startimes Smart', price: 3800.00),
                CablePackage(id: 's_4', provider: 'Startimes', packageName: 'Startimes Classic', price: 5000.00),
              ],
            },
          ),
        ) {
    loadSavedBillers();
  }

  Future<void> loadSavedBillers() async {
    if (!Env.isMockMode && defaultApiClient.baseUrl.isNotEmpty) {
      try {
        final res = await defaultApiClient.get('/v1/users/beneficiaries');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['beneficiaries'] != null && data['beneficiaries'] is List) {
            final list = (data['beneficiaries'] as List)
                .map((b) => Beneficiary.fromJson(b))
                .where((b) => b.category == 'bills' || b.category == 'airtime')
                .toList();
            if (list.isNotEmpty) {
              state = state.copyWith(savedBillers: list);
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> fetchDataPlans(String network) async {
    final netSlug = network.toLowerCase();
    state = state.copyWith(
      isLoadingDataPlans: true,
      dataPlansError: null,
      currentNetwork: netSlug,
    );

    if (Env.isMockMode) {
      final mockPlans = _getMockDataPlans(netSlug);
      state = state.copyWith(
        dataPlans: mockPlans,
        isLoadingDataPlans: false,
      );
      return;
    }

    try {
      final response = await defaultApiClient.get('/v1/vtpass/data-plans?network=$netSlug');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> variations = json['content']?['varations'] ?? [];
        if (variations.isNotEmpty) {
          final fetchedPlans = variations
              .map((v) => DataPlan.fromVtpassJson(v as Map<String, dynamic>))
              .toList();
          state = state.copyWith(
            dataPlans: fetchedPlans,
            isLoadingDataPlans: false,
          );
          return;
        }
      }
      state = state.copyWith(
        isLoadingDataPlans: false,
        dataPlansError: 'Failed to load data plans for ${network.toUpperCase()}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingDataPlans: false,
        dataPlansError: 'Network connection error while fetching data plans',
      );
    }
  }

  Future<Map<String, dynamic>> verifyMeter({
    required String meterNumber,
    required String disco,
    required String type,
  }) async {
    if (Env.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return {
        'status': 'success',
        'customerName': 'CHUKWUMA UGOBUEZE',
        'address': '12 PAYFLOW WAY, VICTORIA ISLAND, LAGOS',
        'meterNumber': meterNumber,
      };
    }

    try {
      final response = await defaultApiClient.post(
        '/v1/vtpass/verify-meter',
        body: {
          'billersCode': meterNumber,
          'serviceID': disco.toLowerCase().replaceAll(' ', '-'),
          'type': type.toLowerCase(),
        },
      );

      final json = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final content = json['content'];
        if (content != null && content['Customer_Name'] != null) {
          return {
            'status': 'success',
            'customerName': content['Customer_Name'],
            'address': content['Address'] ?? 'N/A',
            'meterNumber': content['Meter_Number'] ?? meterNumber,
          };
        }
      }

      final errorDesc = json['response_description'] ?? json['error'] ?? 'Meter verification failed';
      throw Exception(errorDesc);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error during meter verification');
    }
  }

  Future<Map<String, dynamic>> verifySmartcard({
    required String smartcardNumber,
    required String provider,
  }) async {
    if (Env.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return {
        'status': 'success',
        'customerName': 'CHUKWUMA UGOBUEZE',
        'smartcardNumber': smartcardNumber,
        'currentPackage': 'DSTV Compact',
      };
    }

    try {
      final response = await defaultApiClient.post(
        '/v1/vtpass/verify-smartcard',
        body: {
          'billersCode': smartcardNumber,
          'serviceID': provider.toLowerCase(),
        },
      );

      final json = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final content = json['content'];
        if (content != null && content['Customer_Name'] != null) {
          return {
            'status': 'success',
            'customerName': content['Customer_Name'],
            'smartcardNumber': content['Customer_Number'] ?? smartcardNumber,
            'currentPackage': content['Current_Bouquet'] ?? 'Active Package',
          };
        }
      }

      final errorDesc = json['response_description'] ?? json['error'] ?? 'Smartcard verification failed';
      throw Exception(errorDesc);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error during smartcard verification');
    }
  }

  List<DataPlan> _getMockDataPlans(String netSlug) {
    switch (netSlug.toLowerCase()) {
      case 'glo':
        return [
          const DataPlan(id: 'glo_1', name: 'GLO 1GB Data Plan', validity: '30 Days', price: 1000.00, variationCode: 'glo-1gb-1000'),
          const DataPlan(id: 'glo_2', name: 'GLO 2.5GB Data Plan', validity: '30 Days', price: 1500.00, variationCode: 'glo-2.5gb-1500'),
          const DataPlan(id: 'glo_3', name: 'GLO 5.8GB Data Plan', validity: '30 Days', price: 2500.00, variationCode: 'glo-5.8gb-2500'),
          const DataPlan(id: 'glo_4', name: 'GLO 10GB Data Plan', validity: '30 Days', price: 4000.00, variationCode: 'glo-10gb-4000'),
        ];
      case 'airtel':
        return [
          const DataPlan(id: 'air_1', name: 'Airtel 750MB Data Plan', validity: '14 Days', price: 500.00, variationCode: 'airtel-750mb-500'),
          const DataPlan(id: 'air_2', name: 'Airtel 1.5GB Data Plan', validity: '30 Days', price: 1000.00, variationCode: 'airtel-1.5gb-1000'),
          const DataPlan(id: 'air_3', name: 'Airtel 3GB Data Plan', validity: '30 Days', price: 1500.00, variationCode: 'airtel-3gb-1500'),
          const DataPlan(id: 'air_4', name: 'Airtel 4.5GB Data Plan', validity: '30 Days', price: 2000.00, variationCode: 'airtel-4.5gb-2000'),
        ];
      case '9mobile':
        return [
          const DataPlan(id: '9m_1', name: '9mobile 1GB Data Plan', validity: '30 Days', price: 1000.00, variationCode: '9mobile-1gb-1000'),
          const DataPlan(id: '9m_2', name: '9mobile 2.5GB Data Plan', validity: '30 Days', price: 1500.00, variationCode: '9mobile-2.5gb-1500'),
          const DataPlan(id: '9m_3', name: '9mobile 4.5GB Data Plan', validity: '30 Days', price: 2000.00, variationCode: '9mobile-4.5gb-2000'),
          const DataPlan(id: '9m_4', name: '9mobile 11GB Data Plan', validity: '30 Days', price: 4000.00, variationCode: '9mobile-11gb-4000'),
        ];
      case 'mtn':
      default:
        return [
          const DataPlan(id: 'mtn_1', name: '500MB Data Plan', validity: '1 Day', price: 300.00, variationCode: 'mtn-500mb-300'),
          const DataPlan(id: 'mtn_2', name: '1.5GB Data Plan', validity: '30 Days', price: 1000.00, variationCode: 'mtn-1.5gb-1000'),
          const DataPlan(id: 'mtn_3', name: '3GB Data Plan', validity: '30 Days', price: 1500.00, variationCode: 'mtn-3gb-1500'),
          const DataPlan(id: 'mtn_4', name: '5GB Data Plan', validity: '30 Days', price: 2500.00, variationCode: 'mtn-5gb-2500'),
          const DataPlan(id: 'mtn_5', name: '10GB Data Plan', validity: '30 Days', price: 5000.00, variationCode: 'mtn-10gb-5000'),
          const DataPlan(id: 'mtn_6', name: '20GB Data Plan', validity: '30 Days', price: 9000.00, variationCode: 'mtn-20gb-9000'),
        ];
    }
  }
}

final servicesViewModelProvider =
    StateNotifierProvider<ServicesViewModel, ServicesState>((ref) {
  return ServicesViewModel();
});
