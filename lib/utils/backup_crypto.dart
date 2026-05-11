import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Phase 6.3 — encrypted backup envelopes.
///
/// Wraps a plaintext JSON backup in an AES-GCM ciphertext envelope keyed
/// off a user-provided passphrase. The envelope is portable across
/// devices (it carries its own salt + IV) and survives version upgrades
/// because the version field stays in the envelope, not under encryption.
///
/// File format (v4):
/// ```
/// {
///   "version": 4,
///   "encrypted": true,
///   "salt": "<base64 16 bytes>",
///   "iv":   "<base64 12 bytes>",
///   "ciphertext": "<base64 …>",
///   "tag":  "<base64 16 bytes>"
/// }
/// ```
///
/// The legacy v3 envelope is plaintext JSON with `encrypted: false` (or
/// no `encrypted` field at all). Restore must handle both.
class BackupCrypto {
  BackupCrypto._();

  /// Envelope version this codec writes. Phase 4.9 shipped v3.
  static const int envelopeVersion = 4;

  /// PBKDF2 iteration count. 100_000 matches `MASTER_PLAN.md` §6.3 and is
  /// the floor recommended by OWASP for SHA-256 PBKDF2 on mobile.
  static const int pbkdf2Iterations = 100000;

  /// 256-bit AES-GCM key.
  static const int _keyLengthBytes = 32;

  /// 128-bit salt for PBKDF2.
  static const int _saltLengthBytes = 16;

  /// 96-bit GCM IV (the spec-recommended length).
  static const int _ivLengthBytes = 12;

  /// Encrypts [json] under [passphrase] and returns the v4 envelope as a
  /// JSON-encoded string ready to be written to disk.
  ///
  /// Each call generates a fresh random salt and IV — calling
  /// [encrypt] twice with the same input never produces the same output.
  static Future<String> encrypt(String json, String passphrase) async {
    if (passphrase.isEmpty) {
      throw ArgumentError.value(
        passphrase,
        'passphrase',
        'Passphrase must not be empty.',
      );
    }
    final algorithm = AesGcm.with256bits();
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: _keyLengthBytes * 8,
    );

    final random = SecureRandom.fast;
    final salt = _randomBytes(random, _saltLengthBytes);
    final iv = _randomBytes(random, _ivLengthBytes);

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );

    final secretBox = await algorithm.encrypt(
      utf8.encode(json),
      secretKey: secretKey,
      nonce: iv,
    );

    final envelope = <String, dynamic>{
      'version': envelopeVersion,
      'encrypted': true,
      'salt': base64Encode(salt),
      'iv': base64Encode(iv),
      'ciphertext': base64Encode(secretBox.cipherText),
      'tag': base64Encode(secretBox.mac.bytes),
    };
    return jsonEncode(envelope);
  }

  /// Decrypts a v4 envelope and returns the plaintext JSON. Returns
  /// `null` if the passphrase is wrong, the envelope is malformed, or
  /// authentication fails (AES-GCM's tag check). Never throws on a
  /// wrong passphrase — the UI distinguishes "wrong passphrase" from
  /// "corrupt file" by reading the version field separately.
  static Future<String?> decrypt(String envelopeJson, String passphrase) async {
    if (passphrase.isEmpty) return null;
    final Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(envelopeJson);
      if (decoded is! Map<String, dynamic>) return null;
      envelope = decoded;
    } on FormatException {
      return null;
    }
    if (envelope['encrypted'] != true) return null;
    final saltB64 = envelope['salt'];
    final ivB64 = envelope['iv'];
    final ctB64 = envelope['ciphertext'];
    final tagB64 = envelope['tag'];
    if (saltB64 is! String ||
        ivB64 is! String ||
        ctB64 is! String ||
        tagB64 is! String) {
      return null;
    }
    final Uint8List salt;
    final Uint8List iv;
    final Uint8List cipherText;
    final Uint8List tag;
    try {
      salt = base64Decode(saltB64);
      iv = base64Decode(ivB64);
      cipherText = base64Decode(ctB64);
      tag = base64Decode(tagB64);
    } on FormatException {
      return null;
    }
    if (salt.length != _saltLengthBytes ||
        iv.length != _ivLengthBytes ||
        tag.length != 16) {
      return null;
    }

    final algorithm = AesGcm.with256bits();
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: _keyLengthBytes * 8,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );

    final secretBox = SecretBox(
      cipherText,
      nonce: iv,
      mac: Mac(tag),
    );

    try {
      final plain = await algorithm.decrypt(secretBox, secretKey: secretKey);
      return utf8.decode(plain);
    } on SecretBoxAuthenticationError {
      // GCM tag mismatch = wrong passphrase OR tampered envelope.
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Lightweight detector — returns true if [text] parses as a v4
  /// encrypted envelope. Used by restore flow to decide whether to
  /// prompt for a passphrase before attempting decode.
  static bool isEncryptedEnvelope(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return false;
      if (decoded['encrypted'] != true) return false;
      if (decoded['version'] is! int) return false;
      return decoded['salt'] is String &&
          decoded['iv'] is String &&
          decoded['ciphertext'] is String &&
          decoded['tag'] is String;
    } on FormatException {
      return false;
    }
  }

  static List<int> _randomBytes(SecureRandom random, int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = random.nextInt(256);
    }
    return out;
  }
}
