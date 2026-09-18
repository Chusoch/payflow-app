import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/env.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_text_field.dart';
import '../models/kyc_tier.dart';
import '../view_models/kyc_view_model.dart';

class KycPersonalInfoScreen extends ConsumerStatefulWidget {
  const KycPersonalInfoScreen({super.key});

  @override
  ConsumerState<KycPersonalInfoScreen> createState() => _KycPersonalInfoScreenState();
}

class _KycPersonalInfoScreenState extends ConsumerState<KycPersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Individual Controllers
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _dobController;
  late TextEditingController _nationalityController;

  // Business Controllers
  late TextEditingController _businessNameController;
  late TextEditingController _regNumberController;
  late TextEditingController _businessEmailController;

  @override
  void initState() {
    super.initState();
    final kycState = ref.read(kycViewModelProvider);

    _firstNameController = TextEditingController(text: kycState.firstName);
    _lastNameController = TextEditingController(text: kycState.lastName);
    _dobController = TextEditingController(
      text: kycState.dob.isNotEmpty
          ? kycState.dob
          : (Env.isMockMode ? '1995-06-15' : ''),
    );
    _nationalityController = TextEditingController(text: kycState.nationality);

    _businessNameController = TextEditingController(text: kycState.businessName);
    _regNumberController = TextEditingController(text: kycState.registrationNumber);
    _businessEmailController = TextEditingController(text: kycState.businessEmail);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _nationalityController.dispose();
    _businessNameController.dispose();
    _regNumberController.dispose();
    _businessEmailController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = DateTime(1995, 6, 15);
    final firstDate = DateTime(1920);
    final lastDate = now;

    DateTime parsedCurrent = initialDate;
    if (_dobController.text.isNotEmpty) {
      final parsed = DateTime.tryParse(_dobController.text);
      if (parsed != null && !parsed.isAfter(lastDate) && !parsed.isBefore(firstDate)) {
        parsedCurrent = parsed;
      }
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: parsedCurrent,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'SELECT DATE OF BIRTH',
    );

    if (selectedDate != null) {
      final year = selectedDate.year.toString().padLeft(4, '0');
      final month = selectedDate.month.toString().padLeft(2, '0');
      final day = selectedDate.day.toString().padLeft(2, '0');
      setState(() {
        _dobController.text = '$year-$month-$day';
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final kycState = ref.read(kycViewModelProvider);
      final notifier = ref.read(kycViewModelProvider.notifier);

      if (kycState.accountType == AccountType.individual) {
        notifier.updatePersonalInfo(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          dob: _dobController.text.trim(),
          nationality: _nationalityController.text.trim(),
        );
      } else {
        notifier.updateBusinessInfo(
          businessName: _businessNameController.text.trim(),
          registrationNumber: _regNumberController.text.trim(),
          businessEmail: _businessEmailController.text.trim(),
        );
      }

      context.push('/kyc/address');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kycState = ref.watch(kycViewModelProvider);
    final kycNotifier = ref.read(kycViewModelProvider.notifier);
    final isIndividual = kycState.accountType == AccountType.individual;

    return Scaffold(
      appBar: AppBar(
        title: Text(isIndividual ? 'Personal Information' : 'Business Information'),
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
                          isIndividual ? 'Tell us about yourself' : 'Tell us about your business',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceXs),
                        Text(
                          isIndividual
                              ? 'Enter your legal information as displayed on official documents.'
                              : 'Enter your registered business details for verification.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppDimensions.spaceLg),

                        if (isIndividual) ...[
                          PayFlowTextField(
                            label: 'First Name',
                            hintText: 'Enter your first name',
                            controller: _firstNameController,
                            validator: (val) => val == null || val.trim().isEmpty ? 'First name is required' : null,
                          ),
                          const SizedBox(height: AppDimensions.spaceMd),

                          PayFlowTextField(
                            label: 'Last Name',
                            hintText: 'Enter your last name',
                            controller: _lastNameController,
                            validator: (val) => val == null || val.trim().isEmpty ? 'Last name is required' : null,
                          ),
                          const SizedBox(height: AppDimensions.spaceMd),

                          PayFlowTextField(
                            label: 'Date of Birth',
                            hintText: 'YYYY-MM-DD',
                            controller: _dobController,
                            readOnly: true,
                            onTap: () => _selectDate(context),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today_rounded, size: AppDimensions.iconSm),
                              onPressed: () => _selectDate(context),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Date of birth is required' : null,
                          ),
                          const SizedBox(height: AppDimensions.spaceMd),

                          DropdownButtonFormField<String>(
                            initialValue: kycState.gender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Male', child: Text('Male')),
                              DropdownMenuItem(value: 'Female', child: Text('Female')),
                              DropdownMenuItem(value: 'Other', child: Text('Other')),
                            ],
                            onChanged: (val) {
                              if (val != null) kycNotifier.updatePersonalInfo(gender: val);
                            },
                          ),
                          const SizedBox(height: AppDimensions.spaceMd),

                          PayFlowTextField(
                            label: 'Nationality',
                            hintText: 'Nigeria',
                            controller: _nationalityController,
                            validator: (val) => val == null || val.trim().isEmpty ? 'Nationality is required' : null,
                          ),
                        ] else ...[
                          PayFlowTextField(
                            label: 'Business / Enterprise Name',
                            hintText: 'e.g. PayFlow Logistics Ltd',
                            controller: _businessNameController,
                            validator: (val) => val == null || val.trim().isEmpty ? 'Business name is required' : null,
                          ),
                          const SizedBox(height: AppDimensions.spaceMd),

                          DropdownButtonFormField<String>(
                            initialValue: kycState.businessType,
                            decoration: const InputDecoration(
                              labelText: 'Business Type',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Sole Proprietorship', child: Text('Sole Proprietorship')),
                              DropdownMenuItem(value: 'Limited Liability Company', child: Text('Limited Liability Company')),
                              DropdownMenuItem(value: 'Partnership', child: Text('Partnership')),
                              DropdownMenuItem(value: 'NGO / Non-Profit', child: Text('NGO / Non-Profit')),
                            ],
                            onChanged: (val) {
                              if (val != null) kycNotifier.updateBusinessInfo(businessType: val);
                            },
                          ),
                          const SizedBox(height: AppDimensions.spaceMd),

                          PayFlowTextField(
                            label: 'CAC / RC Number (Optional)',
                            hintText: 'RC1234567',
                            controller: _regNumberController,
                          ),
                          const SizedBox(height: AppDimensions.spaceMd),

                          PayFlowTextField(
                            label: 'Business Email Address',
                            hintText: 'contact@business.com',
                            keyboardType: TextInputType.emailAddress,
                            controller: _businessEmailController,
                            validator: (val) => val == null || !val.contains('@') ? 'Valid business email is required' : null,
                          ),
                        ],

                        const Spacer(),
                        const SizedBox(height: AppDimensions.spaceLg),

                        PayFlowButton(
                          text: 'Continue',
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
