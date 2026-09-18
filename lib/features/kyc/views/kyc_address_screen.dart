import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_text_field.dart';
import '../constants/nigerian_locations.dart';
import '../models/kyc_tier.dart';
import '../view_models/kyc_view_model.dart';

class KycAddressScreen extends ConsumerStatefulWidget {
  const KycAddressScreen({super.key});

  @override
  ConsumerState<KycAddressScreen> createState() => _KycAddressScreenState();
}

class _KycAddressScreenState extends ConsumerState<KycAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _addressController;
  late TextEditingController _countryController;

  @override
  void initState() {
    super.initState();
    final kycState = ref.read(kycViewModelProvider);

    _addressController = TextEditingController(text: kycState.addressLine);
    _countryController = TextEditingController(text: kycState.country.isEmpty ? 'Nigeria' : kycState.country);

    // Default state and city initialization if empty
    final defaultState = kycState.stateName.isEmpty ? 'Lagos' : kycState.stateName;
    final lgas = NigerianLocations.getLgasForState(defaultState);
    final defaultCity = (kycState.city.isEmpty || !lgas.contains(kycState.city)) ? lgas.first : kycState.city;

    if (kycState.stateName.isEmpty || kycState.city.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(kycViewModelProvider.notifier).updateAddress(
          stateName: defaultState,
          city: defaultCity,
          country: 'Nigeria',
        );
      });
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final notifier = ref.read(kycViewModelProvider.notifier);

      notifier.updateAddress(
        addressLine: _addressController.text.trim(),
        country: _countryController.text.trim(),
      );

      context.push('/kyc/identity');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kycState = ref.watch(kycViewModelProvider);
    final kycNotifier = ref.read(kycViewModelProvider.notifier);
    final isIndividual = kycState.accountType == AccountType.individual;

    final allStates = NigerianLocations.allStates;
    final currentState = allStates.contains(kycState.stateName) ? kycState.stateName : 'Lagos';
    final availableLgas = NigerianLocations.getLgasForState(currentState);
    final currentCity = availableLgas.contains(kycState.city) ? kycState.city : availableLgas.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Address Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - AppDimensions.spaceMd * 2),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIndividual ? 'Residential Address' : 'Business Location',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceXs),
                        Text(
                          isIndividual
                              ? 'Provide your current residential home address.'
                              : 'Provide your main registered operating office address.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppDimensions.spaceLg),

                        PayFlowTextField(
                          label: 'Street Address',
                          hintText: 'e.g. 15 Admiralty Way, Lekki Phase 1',
                          controller: _addressController,
                          validator: (val) => val == null || val.trim().isEmpty ? 'Street address is required' : null,
                        ),
                        const SizedBox(height: AppDimensions.spaceMd),

                        // State Dropdown (36 States + FCT Abuja)
                        DropdownButtonFormField<String>(
                          initialValue: currentState,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            prefixIcon: Icon(Icons.map_outlined),
                          ),
                          items: allStates
                              .map((st) => DropdownMenuItem(
                                    value: st,
                                    child: Text(st),
                                  ))
                              .toList(),
                          onChanged: (newState) {
                            if (newState != null && newState != currentState) {
                              final newLgas = NigerianLocations.getLgasForState(newState);
                              kycNotifier.updateAddress(
                                stateName: newState,
                                city: newLgas.first,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: AppDimensions.spaceMd),

                        // Dependent City / LGA Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: currentCity,
                          decoration: const InputDecoration(
                            labelText: 'City / LGA',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          items: availableLgas
                              .map((lga) => DropdownMenuItem(
                                    value: lga,
                                    child: Text(lga, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (newCity) {
                            if (newCity != null) {
                              kycNotifier.updateAddress(city: newCity);
                            }
                          },
                        ),
                        const SizedBox(height: AppDimensions.spaceMd),

                        PayFlowTextField(
                          label: 'Country',
                          hintText: 'Nigeria',
                          controller: _countryController,
                          validator: (val) => val == null || val.trim().isEmpty ? 'Country is required' : null,
                        ),

                        const Spacer(),
                        const SizedBox(height: AppDimensions.spaceLg),

                        PayFlowButton(
                          text: 'Continue to Identity Verification',
                          onPressed: _submitForm,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
