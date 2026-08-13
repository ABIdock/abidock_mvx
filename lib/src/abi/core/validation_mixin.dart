/// Binary codec buffer validation utilities.

import 'dart:typed_data';

import '../../utils/sdk_exceptions.dart';

/// Validation methods for binary codec buffer operations.
mixin ValidationMixin {
  /// Validates buffer has at least `requiredBytes` starting from `offset`.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to validate
  /// - `offset` - Starting position
  /// - `requiredBytes` - Minimum bytes needed
  /// - `typeName` - Type name for error context (optional)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer is too short
  @pragma('vm:prefer-inline')
  void requireBufferLength(
    Uint8List buffer,
    int offset,
    int requiredBytes, [
    String? typeName,
  ]) {
    if (buffer.length - offset < requiredBytes) {
      final typeInfo = typeName != null ? '$typeName ' : '';
      throw AbiBinaryCodecException(
        '${typeInfo}requires $requiredBytes bytes, but only ${buffer.length - offset} '
        'available at offset $offset (buffer length: ${buffer.length})',
      );
    }
  }

  /// Validates buffer has exactly `requiredBytes` length.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to validate
  /// - `requiredBytes` - Expected exact length
  /// - `typeName` - Type name for error context (optional)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer length doesn't match
  @pragma('vm:prefer-inline')
  void requireExactLength(
    Uint8List buffer,
    int requiredBytes, [
    String? typeName,
  ]) {
    if (buffer.length != requiredBytes) {
      final typeInfo = typeName != null ? '$typeName ' : '';
      throw AbiBinaryCodecException(
        '${typeInfo}requires exactly $requiredBytes bytes, got ${buffer.length}',
      );
    }
  }

  /// Validates offset is within valid range for buffer.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to validate against
  /// - `offset` - Offset position to validate
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If offset is negative or beyond buffer
  @pragma('vm:prefer-inline')
  void requireValidOffset(Uint8List buffer, int offset) {
    if (offset < 0 || offset > buffer.length) {
      throw AbiBinaryCodecException(
        'Invalid offset $offset for buffer of length ${buffer.length}',
      );
    }
  }

  /// Validates offset with specific minimum required bytes.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to validate
  /// - `offset` - Starting offset
  /// - `requiredBytes` - Minimum bytes needed
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If offset is out of range or buffer too short
  @pragma('vm:prefer-inline')
  void requireOffsetWithBytes(Uint8List buffer, int offset, int requiredBytes) {
    if (offset >= buffer.length) {
      throw AbiBinaryCodecException(
        'Offset $offset is beyond buffer length ${buffer.length}',
      );
    }
    if (buffer.length - offset < requiredBytes) {
      throw AbiBinaryCodecException(
        'Buffer too short: need $requiredBytes bytes at offset $offset, '
        'but only ${buffer.length - offset} bytes available',
      );
    }
  }

  /// Validates buffer doesn't exceed maximum allowed length.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to validate
  /// - `maxLength` - Maximum allowed length
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer exceeds maximum
  @pragma('vm:prefer-inline')
  void requireMaxLength(Uint8List buffer, int maxLength) {
    if (buffer.length > maxLength) {
      throw AbiBinaryCodecException(
        'Buffer length ${buffer.length} exceeds maximum $maxLength',
      );
    }
  }

  /// Validates bytes read don't exceed buffer bounds.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer being read
  /// - `offset` - Starting offset
  /// - `bytesRead` - Number of bytes read
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If read exceeds buffer bounds
  @pragma('vm:prefer-inline')
  void requireBytesRead(Uint8List buffer, int offset, int bytesRead) {
    if (bytesRead < 0) {
      throw AbiBinaryCodecException(
        'Invalid bytesRead: $bytesRead (must be >= 0)',
      );
    }
    if (offset + bytesRead > buffer.length) {
      throw AbiBinaryCodecException(
        'Read $bytesRead bytes from offset $offset, exceeding buffer length ${buffer.length}',
      );
    }
  }

  /// Validates buffer meets minimum length requirement.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to validate
  /// - `minLength` - Minimum required length
  /// - `typeName` - Type name for error context (optional)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If buffer is shorter than minimum
  @pragma('vm:prefer-inline')
  void requireMinimumLength(
    Uint8List buffer,
    int minLength, [
    String? typeName,
  ]) {
    if (buffer.length < minLength) {
      final typeInfo = typeName != null ? '$typeName ' : '';
      throw AbiBinaryCodecException(
        '${typeInfo}requires at least $minLength bytes, got ${buffer.length}',
      );
    }
  }

  /// Validates calculated end offset doesn't exceed buffer length.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to validate against
  /// - `offset` - Starting offset
  /// - `length` - Length from offset
  /// - `typeName` - Type name for error context (optional)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If endOffset > buffer.length
  @pragma('vm:prefer-inline')
  void requireEndOffset(
    Uint8List buffer,
    int offset,
    int length, [
    String? typeName,
  ]) {
    final endOffset = offset + length;
    if (endOffset > buffer.length) {
      final typeInfo = typeName != null ? '$typeName: ' : '';
      throw AbiBinaryCodecException(
        '${typeInfo}End offset $endOffset exceeds buffer length ${buffer.length} '
        '(offset: $offset, length: $length)',
      );
    }
  }

  /// Validates offset is not at or beyond buffer end.
  ///
  /// #### Parameters
  /// - `buffer` - Buffer to validate against
  /// - `offset` - Offset to check
  /// - `context` - Error context description (optional)
  ///
  /// #### Throws
  /// - `AbiBinaryCodecException` - If offset >= buffer.length
  @pragma('vm:prefer-inline')
  void requireOffsetInBounds(Uint8List buffer, int offset, [String? context]) {
    if (offset >= buffer.length) {
      final contextInfo = context != null ? ' while $context' : '';
      throw AbiBinaryCodecException(
        'Offset $offset is beyond buffer length ${buffer.length}$contextInfo',
      );
    }
  }
}
