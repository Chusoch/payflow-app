import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/payment/providers/payment_provider.dart';
import '../../../core/payment/services/payment_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_badge.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../../core/widgets/payflow_text_field.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../kyc/models/kyc_tier.dart';
import '../../kyc/view_models/kyc_view_model.dart';
import '../../notifications/view_models/notification_view_model.dart';
import '../view_models/profile_view_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showEditProfileModal(BuildContext context, WidgetRef ref, ProfileState profileState) {
    final nameController = TextEditingController(text: profileState.fullName);
    final emailController = TextEditingController(text: profileState.email);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppDimensions.spaceLg,
            right: AppDimensions.spaceLg,
            top: AppDimensions.spaceLg,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + AppDimensions.spaceLg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Profile',
                      style: Theme.of(modalContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(modalContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  'Update your full name and contact email. These are linked to your wallet and receipts.',
                  style: Theme.of(modalContext).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
                PayFlowTextField(
                  controller: nameController,
                  label: 'Full Name',
                  hintText: 'Enter your full name',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Full name cannot be empty';
                    }
                    if (val.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                PayFlowTextField(
                  controller: emailController,
                  label: 'Email Address (Optional)',
                  hintText: 'e.g. you@example.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(val.trim())) {
                        return 'Please enter a valid email address';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spaceLg),
                PayFlowButton(
                  text: 'Save Changes',
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.of(modalContext).pop();
                      final success = await ref.read(profileViewModelProvider.notifier).updateProfile(
                        fullName: nameController.text.trim(),
                        email: emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
                      );
                      if (success) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully!'),
                            backgroundColor: AppColors.income,
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Failed to update profile. Please try again.'),
                            backgroundColor: AppColors.expense,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangePinDialog(BuildContext context, WidgetRef ref) {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? inlineError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppDimensions.spaceLg,
                right: AppDimensions.spaceLg,
                top: AppDimensions.spaceLg,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + AppDimensions.spaceLg,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Change Transaction PIN',
                          style: Theme.of(modalContext).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      'Enter your current 4-digit PIN to authenticate, then specify your new PIN.',
                      style: Theme.of(modalContext).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceLg),
                    if (inlineError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.spaceSm),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 18),
                            const SizedBox(width: AppDimensions.spaceSm),
                            Expanded(
                              child: Text(
                                inlineError!,
                                style: const TextStyle(color: AppColors.expense, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),
                    ],
                    PayFlowTextField(
                      controller: currentPinController,
                      label: 'Current 4-digit PIN',
                      hintText: '••••',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                      isPassword: true,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.length != 4) {
                          return 'Current PIN must be 4 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                    PayFlowTextField(
                      controller: newPinController,
                      label: 'New 4-digit PIN',
                      hintText: '••••',
                      prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                      isPassword: true,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.length != 4) {
                          return 'New PIN must be 4 digits';
                        }
                        if (val == currentPinController.text) {
                          return 'New PIN must be different from current PIN';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                    PayFlowTextField(
                      controller: confirmPinController,
                      label: 'Confirm New 4-digit PIN',
                      hintText: '••••',
                      prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary),
                      isPassword: true,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val != newPinController.text) {
                          return 'New PINs do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spaceLg),
                    PayFlowButton(
                      text: 'Update PIN',
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(modalContext);
                          final success = await ref.read(authViewModelProvider.notifier).changePin(
                            currentPin: currentPinController.text.trim(),
                            newPin: newPinController.text.trim(),
                            confirmPin: confirmPinController.text.trim(),
                          );

                          if (success) {
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Transaction PIN updated successfully!'),
                                backgroundColor: AppColors.income,
                              ),
                            );
                          } else {
                            final err = ref.read(authViewModelProvider).errorMessage ?? 'Current PIN is incorrect.';
                            setModalState(() {
                              inlineError = err;
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showHelpSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      builder: (modalContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppDimensions.spaceLg,
            right: AppDimensions.spaceLg,
            top: AppDimensions.spaceLg,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + AppDimensions.spaceLg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Help & Support Center',
                      style: Theme.of(modalContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(modalContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: AppColors.primary),
                  title: const Text('Email Support'),
                  subtitle: const Text('support@payflow.app'),
                  onTap: () {
                    Navigator.of(modalContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support email copied: support@payflow.app')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_outlined, color: AppColors.primary),
                  title: const Text('Toll-Free Phone Support'),
                  subtitle: const Text('0800 PAYFLOW (0800 729 3569)'),
                  onTap: () {
                    Navigator.of(modalContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support line: 0800 729 3569')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                  title: const Text('24/7 In-App Live Chat'),
                  subtitle: const Text('Connect with an agent in ~2 minutes'),
                  onTap: () {
                    Navigator.of(modalContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Live Chat queue connected. An agent will respond shortly.')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAvatarOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      builder: (modalCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(modalCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Take a photo selected')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Choose from albums'),
              onTap: () {
                Navigator.of(modalCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Choose from albums selected')),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: AppColors.expense),
              title: const Text('Cancel', style: TextStyle(color: AppColors.expense)),
              onTap: () => Navigator.of(modalCtx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      builder: (modalCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(modalCtx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(modalCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                title: const Text('Change Transaction PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(modalCtx).pop();
                  _showChangePinDialog(context, ref);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.tune_rounded, color: AppColors.primary),
                title: const Text('Notification Preferences'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(modalCtx).pop();
                  context.push('/notifications/preferences');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: const Text('Edit Profile'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(modalCtx).pop();
                  _showEditProfileModal(context, ref, ref.read(profileViewModelProvider));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      builder: (modalContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Privacy Policy & Terms',
                    style: Theme.of(modalContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(modalContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              Text(
                'NDPR & CBN Compliance',
                style: Theme.of(modalContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'PayFlow operates in strict compliance with the Nigeria Data Protection Regulation (NDPR) and Central Bank of Nigeria (CBN) regulatory guidelines. Your personal identity details, BVN, and financial records are encrypted end-to-end and never sold to third parties.',
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              Text(
                'Account Data & Security',
                style: Theme.of(modalContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'We retain transaction ledgers strictly for accounting, anti-money laundering (AML), and regulatory auditing. You have the right to request access to your data or request account closure at any time through our verified support channels.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileState = ref.watch(profileViewModelProvider);
    final profileNotifier = ref.read(profileViewModelProvider.notifier);
    final kycState = ref.watch(kycViewModelProvider);

    final tierInfo = KycTierInfo.getTierInfo(kycState.tierLevel);

    final displayName = profileState.fullName.isNotEmpty
        ? profileState.fullName
        : (profileState.displayName.isNotEmpty ? profileState.displayName : 'User');

    final String firstName;
    if (profileState.fullName.trim().isNotEmpty) {
      firstName = profileState.fullName.trim().split(' ').first;
    } else if (profileState.displayName.trim().isNotEmpty &&
        !profileState.displayName.startsWith('User +') &&
        !profileState.displayName.startsWith('User 0')) {
      firstName = profileState.displayName.trim().split(' ').first;
    } else {
      firstName = 'User';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileModal(context, ref, profileState),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => _showSettingsModal(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Avatar & Tag Header (OPay Style with Camera Overlay)
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _showAvatarOptionsSheet(context),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              firstName.isNotEmpty
                                  ? firstName.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 34,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceSm + 2),
                    Text(
                      'Hi, $firstName',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Account No: ${profileState.accountNumber.isNotEmpty ? profileState.accountNumber : '--'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (profileState.accountNumber.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: profileState.accountNumber));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Account number copied to clipboard!'),
                                  backgroundColor: AppColors.income,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit Profile'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: () => _showEditProfileModal(context, ref, profileState),
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    GestureDetector(
                      onTap: () {
                        if (kycState.status == KycStatus.verified) {
                          context.push('/kyc/status');
                        } else {
                          context.push('/kyc/intro');
                        }
                      },
                      child: PayFlowBadge(
                        label: kycState.status == KycStatus.verified
                            ? '${tierInfo.title.split(" — ").first} (Verified)'
                            : (profileState.phoneNumber.isNotEmpty
                                ? '${tierInfo.title.split(" — ").first} (Active)'
                                : '${tierInfo.title.split(" — ").first} (Unverified)'),
                        status: kycState.status == KycStatus.verified
                            ? PayFlowBadgeStatus.success
                            : (profileState.phoneNumber.isNotEmpty
                                ? PayFlowBadgeStatus.info
                                : PayFlowBadgeStatus.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // Account Information Card (Grouped Card Format)
              Text(
                'Account Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              PayFlowCard(
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Account Number',
                      value: profileState.accountNumber.isNotEmpty
                          ? profileState.accountNumber
                          : '--',
                    ),
                    const Divider(height: AppDimensions.spaceLg),
                    _InfoRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Account Tier',
                      value: profileState.kycLevel.isNotEmpty
                          ? profileState.kycLevel
                          : (kycState.status == KycStatus.verified
                              ? '${tierInfo.title.split(" — ").first} (Verified)'
                              : (profileState.phoneNumber.isNotEmpty
                                  ? '${tierInfo.title.split(" — ").first} (Active)'
                                  : '${tierInfo.title.split(" — ").first} (Unverified)')),
                    ),
                    const Divider(height: AppDimensions.spaceLg),
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Full Name',
                      value: profileState.fullName.isNotEmpty
                          ? profileState.fullName
                          : displayName,
                    ),
                    const Divider(height: AppDimensions.spaceLg),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Mobile Number',
                      value: profileState.phoneNumber.isNotEmpty
                          ? profileState.phoneNumber
                          : 'Not available',
                    ),
                    const Divider(height: AppDimensions.spaceLg),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: profileState.email.isNotEmpty
                          ? profileState.email
                          : 'Not set (Tap to add)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // App Preferences
              Text(
                'App Preferences',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              PayFlowCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppDimensions.spaceSm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appearance Theme',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceSm),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.light,
                                  label: Text('Light'),
                                  icon: Icon(Icons.light_mode_outlined, size: 16),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.dark,
                                  label: Text('Dark'),
                                  icon: Icon(Icons.dark_mode_outlined, size: 16),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.system,
                                  label: Text('System'),
                                  icon: Icon(Icons.brightness_auto_outlined, size: 16),
                                ),
                              ],
                              selected: {profileState.themeMode},
                              onSelectionChanged: (newSelection) {
                                profileNotifier.setThemeMode(newSelection.first);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: AppDimensions.spaceSm),
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint_rounded),
                      title: const Text('Biometric Authentication'),
                      subtitle: const Text('Use Face ID / Touch ID to sign in'),
                      value: profileState.isBiometricsEnabled,
                      onChanged: (value) {
                        profileNotifier.toggleBiometrics(value);
                      },
                    ),
                    const Divider(height: AppDimensions.spaceSm),
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_outlined),
                      title: const Text('Push Notifications'),
                      subtitle: const Text('Get transaction & security alerts'),
                      value: profileState.isNotificationsEnabled,
                      onChanged: (value) {
                        profileNotifier.toggleNotifications(value);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: const Text('Notification Center'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ref.watch(notificationViewModelProvider).unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${ref.watch(notificationViewModelProvider).unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      onTap: () => context.push('/notifications'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.tune_rounded),
                      title: const Text('Notification Preferences'),
                      subtitle: const Text('Category alert toggles'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/notifications/preferences'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // Support & Security Card
              Text(
                'Security & Support',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              PayFlowCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline_rounded),
                      title: const Text('Change Transaction PIN'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showChangePinDialog(context, ref),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.help_outline_rounded),
                      title: const Text('Help & Support Center'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showHelpSupportModal(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.policy_outlined),
                      title: const Text('Privacy Policy & Terms'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showPrivacyPolicyModal(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              if (!kReleaseMode) ...[
                Text(
                  'Developer Options',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                PayFlowCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Payment Provider (Dev Runtime Toggle)',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppDimensions.spaceSm),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<PaymentProviderType>(
                            segments: const [
                              ButtonSegment<PaymentProviderType>(
                                value: PaymentProviderType.mock,
                                label: Text('Mock'),
                                icon: Icon(Icons.developer_mode_rounded, size: 16),
                              ),
                              ButtonSegment<PaymentProviderType>(
                                value: PaymentProviderType.paystack,
                                label: Text('Paystack'),
                                icon: Icon(Icons.account_balance_wallet_rounded, size: 16),
                              ),
                            ],
                            selected: {ref.watch(paymentServiceProvider).activeProviderType},
                            onSelectionChanged: (newSelection) {
                              ref.read(paymentServiceProvider.notifier).selectProvider(newSelection.first);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceXl),
              ],

              // Real Logout Action
              PayFlowButton(
                text: 'Log Out',
                variant: PayFlowButtonVariant.outline,
                onPressed: () async {
                  await ref.read(authViewModelProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: AppDimensions.iconMd),
        const SizedBox(width: AppDimensions.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
