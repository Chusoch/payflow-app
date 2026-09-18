import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/pdf_generator_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../view_models/wallet_view_model.dart';

class StatementExportSheet extends ConsumerStatefulWidget {
  final bool isWeb;

  const StatementExportSheet({
    super.key,
    this.isWeb = kIsWeb,
  });

  static Future<void> show(BuildContext context, {bool isWeb = kIsWeb}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatementExportSheet(isWeb: isWeb),
    );
  }

  @override
  ConsumerState<StatementExportSheet> createState() => _StatementExportSheetState();
}

class _StatementExportSheetState extends ConsumerState<StatementExportSheet> {
  String _selectedPreset = 'Last 30 Days';
  String _selectedCategory = 'All';
  late DateTimeRange _dateRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
  }

  void _updatePreset(String preset) async {
    final now = DateTime.now();
    if (preset == 'Last 7 Days') {
      setState(() {
        _selectedPreset = preset;
        _dateRange = DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
      });
    } else if (preset == 'Last 30 Days') {
      setState(() {
        _selectedPreset = preset;
        _dateRange = DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
      });
    } else if (preset == 'Custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _dateRange,
      );
      if (picked != null) {
        setState(() {
          _selectedPreset = 'Custom';
          _dateRange = picked;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final walletState = ref.watch(walletViewModelProvider);
    final categories = ['All', 'Transfers', 'Airtime', 'Data', 'Bills', 'Wallet Funding'];

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spaceSm),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Text(
                      'Account Statement',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Date Range Selection
            Text(
              'Select Date Range',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceXs),
            Row(
              children: ['Last 7 Days', 'Last 30 Days', 'Custom'].map((preset) {
                final isSelected = _selectedPreset == preset;
                return Padding(
                  padding: const EdgeInsets.only(right: AppDimensions.spaceSm),
                  child: FilterChip(
                    label: Text(preset),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) => _updatePreset(preset),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Category Filter Selection
            Text(
              'Filter by Transaction Category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceXs),
            Wrap(
              spacing: AppDimensions.spaceXs,
              runSpacing: AppDimensions.spaceXs,
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: PayFlowButton(
                    text: 'Share',
                    icon: const Icon(Icons.share_rounded, size: 18),
                    variant: PayFlowButtonVariant.outline,
                    onPressed: () {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.of(context).pop();
                      PdfGeneratorService.shareStatementPdf(
                        transactions: walletState.transactions,
                        dateRange: _dateRange,
                        categoryFilter: _selectedCategory,
                        currentBalance: walletState.mainBalance,
                        messenger: messenger,
                        isWebOverride: widget.isWeb,
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceMd),
                Expanded(
                  child: PayFlowButton(
                    text: 'Download PDF',
                    icon: const Icon(Icons.download_rounded, size: 18),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.of(context).pop();
                      try {
                        final path = await PdfGeneratorService.downloadStatementPdf(
                          transactions: walletState.transactions,
                          dateRange: _dateRange,
                          categoryFilter: _selectedCategory,
                          currentBalance: walletState.mainBalance,
                          isWebOverride: widget.isWeb,
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(widget.isWeb
                                ? 'Statement downloaded: ${path.split('/').last}'
                                : 'Statement downloaded & saved: ${path.split('/').last}'),
                            backgroundColor: AppColors.income,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to download statement: $e'),
                            backgroundColor: AppColors.expense,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceSm),
          ],
        ),
      ),
    );
  }
}
