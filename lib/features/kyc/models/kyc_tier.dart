enum KycTierLevel {
  tier1,
  tier2,
  tier3,
}

enum KycStatus {
  notStarted,
  inProgress,
  pending,
  verified,
  failed,
}

enum AccountType {
  individual,
  business,
}

class KycTierInfo {
  final KycTierLevel level;
  final String title;
  final String subtitle;
  final double dailyLimit;
  final double singleTransactionLimit;
  final List<String> requirements;

  const KycTierInfo({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.dailyLimit,
    required this.singleTransactionLimit,
    required this.requirements,
  });

  static KycTierInfo getTierInfo(KycTierLevel level) {
    switch (level) {
      case KycTierLevel.tier1:
        return const KycTierInfo(
          level: KycTierLevel.tier1,
          title: 'Tier 1 — Basic',
          subtitle: 'Basic account features with starter limits.',
          dailyLimit: 50000.0,
          singleTransactionLimit: 20000.0,
          requirements: [
            'Phone Number Verification',
            'Basic Personal Information',
          ],
        );
      case KycTierLevel.tier2:
        return const KycTierInfo(
          level: KycTierLevel.tier2,
          title: 'Tier 2 — Standard',
          subtitle: 'Higher limits for daily transactions.',
          dailyLimit: 200000.0,
          singleTransactionLimit: 100000.0,
          requirements: [
            'BVN Verification',
            'NIN Verification',
            'Residential / Business Address',
          ],
        );
      case KycTierLevel.tier3:
        return const KycTierInfo(
          level: KycTierLevel.tier3,
          title: 'Tier 3 — Premium',
          subtitle: 'Maximum transaction limits and full feature access.',
          dailyLimit: 5000000.0,
          singleTransactionLimit: 1000000.0,
          requirements: [
            'Selfie / Liveness Verification',
            'Government ID / CAC Document Upload',
            'Proof of Address Verification',
          ],
        );
    }
  }
}
