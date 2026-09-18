/// Table of Nigerian MSISDN network operator prefixes.
class NetworkPrefixes {
  static const Map<String, List<String>> prefixMap = {
    'mtn': [
      '0803', '0806', '0814', '0810', '0813', '0816', '0703', '0706', '0903', '0906', '0913', '0916', '07025', '07026', '0704'
    ],
    'glo': [
      '0805', '0807', '0811', '0815', '0705', '0905', '0915'
    ],
    'airtel': [
      '0802', '0808', '0812', '0701', '0708', '0902', '0907', '0901', '0912'
    ],
    '9mobile': [
      '0809', '0817', '0818', '0909', '0908'
    ],
  };

  /// Detects network operator slug ('mtn', 'glo', 'airtel', '9mobile') from phone number.
  static String detectNetwork(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    String localPhone = cleaned;
    if (cleaned.startsWith('234') && cleaned.length >= 13) {
      localPhone = '0${cleaned.substring(3)}';
    }

    if (localPhone.length >= 4) {
      final prefix4 = localPhone.substring(0, 4);
      for (final entry in prefixMap.entries) {
        if (entry.value.contains(prefix4)) {
          return entry.key;
        }
      }
    }

    return 'mtn'; // Default network operator
  }
}
