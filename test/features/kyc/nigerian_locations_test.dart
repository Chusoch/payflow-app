import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/features/kyc/constants/nigerian_locations.dart';

void main() {
  group('NigerianLocations Unit Tests', () {
    test('allStates returns 37 states including FCT - Abuja', () {
      final states = NigerianLocations.allStates;
      expect(states.length, 37);
      expect(states.contains('Lagos'), isTrue);
      expect(states.contains('FCT - Abuja'), isTrue);
      expect(states.contains('Rivers'), isTrue);
      expect(states.contains('Kano'), isTrue);
    });

    test('getLgasForState returns valid LGAs for Lagos', () {
      final lagosLgas = NigerianLocations.getLgasForState('Lagos');
      expect(lagosLgas, isNotEmpty);
      expect(lagosLgas.contains('Ikeja'), isTrue);
      expect(lagosLgas.contains('Alimosho'), isTrue);
    });

    test('getLgasForState returns valid LGAs for FCT - Abuja', () {
      final abujaLgas = NigerianLocations.getLgasForState('FCT - Abuja');
      expect(abujaLgas, isNotEmpty);
      expect(abujaLgas.contains('Abuja Municipal (AMAC)'), isTrue);
    });
  });
}
