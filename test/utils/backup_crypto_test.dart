import 'dart:convert';

import 'package:budget_tracker/utils/backup_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 6.3 — AES-GCM + PBKDF2 envelope for backup files.
///
/// These tests pin the contract that ships in the v5 release:
/// 1. Round-trip with the same passphrase recovers the plaintext.
/// 2. Wrong passphrase returns `null`, never the wrong plaintext, never throws.
/// 3. Repeated encrypts with the same input produce different ciphertext
///    (fresh IV every time — GCM's correctness depends on it).
/// 4. The envelope advertises version 4 + `encrypted: true` so the
///    restore flow can branch off the legacy v3 plaintext path.
/// 5. Tampering with any envelope field is rejected by the GCM tag.
void main() {
  const samplePlaintext = '''
    {"version":3,"expenses":[{"id":1,"amount":12.34,"description":"coffee"}]}
  ''';
  const passphrase = 'correct horse battery staple';

  group('BackupCrypto.encrypt', () {
    test('round-trips with same passphrase', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final recovered = await BackupCrypto.decrypt(envelope, passphrase);
      expect(recovered, samplePlaintext);
    });

    test('refuses empty passphrase on encrypt', () async {
      await expectLater(
        BackupCrypto.encrypt(samplePlaintext, ''),
        throwsArgumentError,
      );
    });

    test('produces v4 envelope shape', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      expect(decoded['version'], BackupCrypto.envelopeVersion);
      expect(decoded['version'], 4);
      expect(decoded['encrypted'], isTrue);
      expect(decoded['salt'], isA<String>());
      expect(decoded['iv'], isA<String>());
      expect(decoded['ciphertext'], isA<String>());
      expect(decoded['tag'], isA<String>());
      // Salt is 16 bytes → 24 chars of base64.
      expect((base64Decode(decoded['salt'] as String)).length, 16);
      // IV is 12 bytes → 16 chars of base64.
      expect((base64Decode(decoded['iv'] as String)).length, 12);
      // GCM tag is 16 bytes.
      expect((base64Decode(decoded['tag'] as String)).length, 16);
    });

    test('produces different ciphertext on repeated encrypts of same plaintext', () async {
      final first = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final second = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final firstDecoded = jsonDecode(first) as Map<String, dynamic>;
      final secondDecoded = jsonDecode(second) as Map<String, dynamic>;
      // IVs must differ — otherwise GCM is catastrophically broken.
      expect(firstDecoded['iv'], isNot(secondDecoded['iv']));
      // Ciphertexts must differ as a consequence.
      expect(firstDecoded['ciphertext'], isNot(secondDecoded['ciphertext']));
      // Both should still round-trip.
      expect(await BackupCrypto.decrypt(first, passphrase), samplePlaintext);
      expect(await BackupCrypto.decrypt(second, passphrase), samplePlaintext);
    });

    // Spec gap (encrypt case 5): a small ASCII sample was the only payload
    // exercised. A real backup carries multibyte UTF-8 (emoji descriptions,
    // accented locale strings) and is much larger. UTF-8 encode/decode must
    // survive the AES-GCM round-trip byte-for-byte.
    test('round-trips a large multibyte UTF-8 payload byte-for-byte', () async {
      // Mix of emoji, accented Latin, CJK, RTL, and currency symbols —
      // exactly the kind of free-text that lands in expense descriptions.
      const unicodeUnit =
          '☕ café ¥ 1,234 — 日本語 — مرحبا — naïve façade €£₹ 🧾💸 ';
      final buffer = StringBuffer('{"version":3,"expenses":[');
      for (var i = 0; i < 500; i++) {
        if (i > 0) buffer.write(',');
        buffer.write(
          '{"id":$i,"amount":12.34,"description":"$unicodeUnit#$i"}',
        );
      }
      buffer.write(']}');
      final largePlaintext = buffer.toString();
      // Sanity: the payload is genuinely large and genuinely multibyte.
      expect(largePlaintext.length, greaterThan(10000));
      expect(utf8.encode(largePlaintext).length,
          greaterThan(largePlaintext.length),
          reason: 'payload must contain multibyte UTF-8 to be a real test.');

      final envelope = await BackupCrypto.encrypt(largePlaintext, passphrase);
      final recovered = await BackupCrypto.decrypt(envelope, passphrase);
      expect(recovered, largePlaintext);
    });
  });

  group('BackupCrypto.decrypt', () {
    test('returns null on wrong passphrase (never throws)', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final out = await BackupCrypto.decrypt(envelope, 'wrong');
      expect(out, isNull);
    });

    test('returns null on empty passphrase', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final out = await BackupCrypto.decrypt(envelope, '');
      expect(out, isNull);
    });

    test('returns null on plaintext (non-envelope) input', () async {
      // A v3 plaintext file shouldn't be silently mis-decoded.
      const v3 = '{"version":3,"encrypted":false,"expenses":[]}';
      final out = await BackupCrypto.decrypt(v3, passphrase);
      expect(out, isNull);
    });

    test('returns null on malformed JSON', () async {
      final out = await BackupCrypto.decrypt('not json {{{', passphrase);
      expect(out, isNull);
    });

    test('returns null when ciphertext has been tampered with', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      // Flip a single byte in the ciphertext.
      final cipherBytes = base64Decode(decoded['ciphertext'] as String);
      cipherBytes[0] ^= 0x01;
      decoded['ciphertext'] = base64Encode(cipherBytes);
      final tampered = jsonEncode(decoded);
      final out = await BackupCrypto.decrypt(tampered, passphrase);
      expect(out, isNull,
          reason: 'GCM tag must reject any flipped-bit ciphertext.');
    });

    test('returns null when salt length is wrong', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      decoded['salt'] = base64Encode([1, 2, 3]); // 3 bytes, not 16
      final out = await BackupCrypto.decrypt(jsonEncode(decoded), passphrase);
      expect(out, isNull);
    });

    // Spec gap (decrypt case 6): only the ciphertext was previously
    // bit-flipped. AES-GCM authenticates the IV and the tag too, so flipping
    // either must also be rejected by the tag check — never decode to garbage.
    test('returns null when the IV has been tampered with', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      final ivBytes = base64Decode(decoded['iv'] as String);
      ivBytes[0] ^= 0x01; // flip one bit, keep the 12-byte length valid
      decoded['iv'] = base64Encode(ivBytes);
      final out = await BackupCrypto.decrypt(jsonEncode(decoded), passphrase);
      expect(out, isNull,
          reason: 'a flipped IV bit must fail GCM authentication.');
    });

    test('returns null when the tag has been tampered with', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      final tagBytes = base64Decode(decoded['tag'] as String);
      tagBytes[0] ^= 0x01; // flip one bit, keep the 16-byte length valid
      decoded['tag'] = base64Encode(tagBytes);
      final out = await BackupCrypto.decrypt(jsonEncode(decoded), passphrase);
      expect(out, isNull,
          reason: 'a flipped tag bit must fail GCM authentication.');
    });

    // Spec gap (decrypt case 7): the length guard rejects each field
    // independently. Salt-length was already covered; pin iv and tag too.
    test('returns null when the IV length is wrong', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      decoded['iv'] = base64Encode([1, 2, 3]); // 3 bytes, not 12
      final out = await BackupCrypto.decrypt(jsonEncode(decoded), passphrase);
      expect(out, isNull);
    });

    test('returns null when the tag length is wrong', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      decoded['tag'] = base64Encode([1, 2, 3]); // 3 bytes, not 16
      final out = await BackupCrypto.decrypt(jsonEncode(decoded), passphrase);
      expect(out, isNull);
    });

    // Spec gap (decrypt case 8): a field that isn't valid base64 makes
    // base64Decode throw FormatException, which decrypt swallows → null.
    test('returns null when a field is not valid base64', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      // '!!!!' is a 4-char string (passes the `is String` guard) but every
      // character is outside the base64 alphabet → base64Decode throws.
      decoded['ciphertext'] = '!!!!';
      final out = await BackupCrypto.decrypt(jsonEncode(decoded), passphrase);
      expect(out, isNull);
    });

    test('returns null when a field is present but not a String', () async {
      // The `is! String` guard fires before any base64 work.
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      decoded['iv'] = 12345; // number, not a base64 string
      final out = await BackupCrypto.decrypt(jsonEncode(decoded), passphrase);
      expect(out, isNull);
    });

    // Spec gap (decrypt case 9): top-level JSON that decodes to something
    // other than a Map (a List, a bare number, a string) must return null,
    // not throw a cast error.
    test('returns null when top-level JSON is a List', () async {
      final out = await BackupCrypto.decrypt('[1,2,3]', passphrase);
      expect(out, isNull);
    });

    test('returns null when top-level JSON is a bare number', () async {
      final out = await BackupCrypto.decrypt('42', passphrase);
      expect(out, isNull);
    });

    test('returns null when top-level JSON is a bare string', () async {
      final out = await BackupCrypto.decrypt('"just a string"', passphrase);
      expect(out, isNull);
    });
  });

  group('BackupCrypto.isEncryptedEnvelope', () {
    test('returns true for a freshly-produced envelope', () async {
      final envelope = await BackupCrypto.encrypt(samplePlaintext, passphrase);
      expect(BackupCrypto.isEncryptedEnvelope(envelope), isTrue);
    });

    test('returns false for plaintext v3 backup', () {
      const v3 =
          '{"version":3,"encrypted":false,"expenses":[],"income":[]}';
      expect(BackupCrypto.isEncryptedEnvelope(v3), isFalse);
    });

    test('returns false for plaintext v3 backup without encrypted field', () {
      const v3 = '{"version":3,"expenses":[],"income":[]}';
      expect(BackupCrypto.isEncryptedEnvelope(v3), isFalse);
    });

    test('returns false for empty / malformed input', () {
      expect(BackupCrypto.isEncryptedEnvelope(''), isFalse);
      expect(BackupCrypto.isEncryptedEnvelope('{{{'), isFalse);
      expect(BackupCrypto.isEncryptedEnvelope('null'), isFalse);
    });

    test('returns false when envelope is missing required fields', () {
      const partial =
          '{"version":4,"encrypted":true,"salt":"x"}'; // no iv, ct, tag
      expect(BackupCrypto.isEncryptedEnvelope(partial), isFalse);
    });

    // Spec gap (isEncryptedEnvelope case 5): `version` must be an int.
    // A quoted "4" (or any non-int) fails the `version is! int` guard even
    // though every other field is well-formed → false.
    test('returns false when version is a string instead of an int', () {
      const stringVersion =
          '{"version":"4","encrypted":true,"salt":"AAAA","iv":"AAAA",'
          '"ciphertext":"AAAA","tag":"AAAA"}';
      expect(BackupCrypto.isEncryptedEnvelope(stringVersion), isFalse);
    });

    test('returns false when version is a double instead of an int', () {
      // JSON 4.0 decodes to a Dart double, which is not an int.
      const doubleVersion =
          '{"version":4.0,"encrypted":true,"salt":"AAAA","iv":"AAAA",'
          '"ciphertext":"AAAA","tag":"AAAA"}';
      expect(BackupCrypto.isEncryptedEnvelope(doubleVersion), isFalse);
    });

    test('returns true when all fields including int version are well-formed', () {
      // The mirror-image positive: same shape as the string-version case but
      // with an integer version → true, proving the guard is what flips it.
      const wellFormed =
          '{"version":4,"encrypted":true,"salt":"AAAA","iv":"AAAA",'
          '"ciphertext":"AAAA","tag":"AAAA"}';
      expect(BackupCrypto.isEncryptedEnvelope(wellFormed), isTrue);
    });
  });
}
