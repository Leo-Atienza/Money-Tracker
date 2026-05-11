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
  });
}
