import 'package:flutter_test/flutter_test.dart';
import 'package:dailykit_app/services/tap_sequence_detector.dart';

void main() {
  group('TapSequenceDetector Unit Tests', () {
    test('Single tap fires only after 600ms sequence timeout', () async {
      int singleTapFired = 0;
      int tripleTapFired = 0;

      final detector = TapSequenceDetector(
        sequenceTimeout: const Duration(milliseconds: 600),
        onSingleTap: () => singleTapFired++,
        onTripleTap: () => tripleTapFired++,
      );

      // 1. Register 1 tap
      detector.registerTap();
      expect(singleTapFired, 0, reason: 'Single tap must not fire immediately');
      expect(tripleTapFired, 0);

      // Wait 300ms (still within sequence)
      await Future.delayed(const Duration(milliseconds: 300));
      expect(singleTapFired, 0, reason: 'Single tap must not fire before 600ms timeout');

      // Wait remaining 350ms (total 650ms elapsed)
      await Future.delayed(const Duration(milliseconds: 350));
      expect(singleTapFired, 1, reason: 'Single tap should fire once sequence timeout ends');
      expect(tripleTapFired, 0);
    });

    test('Triple tap within 600ms fires immediately on 3rd tap without single tap', () async {
      int singleTapFired = 0;
      int tripleTapFired = 0;

      final detector = TapSequenceDetector(
        sequenceTimeout: const Duration(milliseconds: 600),
        onSingleTap: () => singleTapFired++,
        onTripleTap: () => tripleTapFired++,
      );

      // 1st tap
      detector.registerTap();
      await Future.delayed(const Duration(milliseconds: 150));

      // 2nd tap
      detector.registerTap();
      await Future.delayed(const Duration(milliseconds: 150));

      expect(tripleTapFired, 0);
      expect(singleTapFired, 0);

      // 3rd tap
      detector.registerTap();
      expect(tripleTapFired, 1, reason: 'Triple tap must fire immediately on 3rd tap');
      expect(singleTapFired, 0);

      // Wait for any remaining timeout to verify single tap never fires
      await Future.delayed(const Duration(milliseconds: 700));
      expect(singleTapFired, 0, reason: 'Single tap must not fire after triple tap sequence');
      expect(tripleTapFired, 1);
    });

    test('Two taps followed by timeout does not trigger single tap or triple tap', () async {
      int singleTapFired = 0;
      int tripleTapFired = 0;

      final detector = TapSequenceDetector(
        sequenceTimeout: const Duration(milliseconds: 600),
        onSingleTap: () => singleTapFired++,
        onTripleTap: () => tripleTapFired++,
      );

      detector.registerTap();
      await Future.delayed(const Duration(milliseconds: 200));
      detector.registerTap(); // 2 taps total

      await Future.delayed(const Duration(milliseconds: 700)); // wait for timeout
      expect(singleTapFired, 0, reason: 'Single tap only fires for exactly 1 tap');
      expect(tripleTapFired, 0, reason: 'Triple tap requires 3 taps');
    });
  });
}

