/// Efficient buffer builder for binary codec operations.
import 'dart:typed_data';

import '../codecs/codec_base.dart';

/// Efficient binary buffer builder with dynamic growth.
///
/// Builds buffers incrementally with pre-allocation to minimize
/// memory allocations.
class BinaryBuilder {
  /// Creates a binary builder with optional initial capacity.
  ///
  /// #### Parameters
  /// - `initialCapacity` - Pre-allocated capacity in bytes (default: 256)
  BinaryBuilder({int initialCapacity = 256})
    : _buffer = Uint8List(initialCapacity),
      _length = 0;

  /// Internal buffer (may be larger than actual data).
  Uint8List _buffer;

  /// Actual number of bytes written.
  int _length;

  /// Current length of written data.
  int get length => _length;

  /// Remaining capacity before reallocation.
  int get capacity => _buffer.length;

  /// Whether the builder is empty.
  bool get isEmpty => _length == 0;

  /// Whether the builder has data.
  bool get isNotEmpty => _length > 0;

  /// Adds a single byte to the buffer.
  ///
  /// #### Parameters
  /// - `byte` - Byte value (0-255)
  ///
  @pragma('vm:prefer-inline')
  void addByte(int byte) {
    _ensureCapacity(1);
    _buffer[_length++] = byte;
  }

  /// Adds multiple bytes to the buffer.
  ///
  /// #### Parameters
  /// - `bytes` - Byte buffer to append
  ///
  @pragma('vm:prefer-inline')
  void addBytes(Uint8List bytes) {
    if (bytes.isEmpty) return;

    _ensureCapacity(bytes.length);
    _buffer.setRange(_length, _length + bytes.length, bytes);
    _length += bytes.length;
  }

  /// Adds a 32-bit unsigned integer in big-endian format.
  ///
  /// #### Parameters
  /// - `value` - U32 value to encode
  ///
  @pragma('vm:prefer-inline')
  void addU32(int value) {
    _ensureCapacity(4);
    _buffer[_length++] = (value >> 24) & 0xFF;
    _buffer[_length++] = (value >> 16) & 0xFF;
    _buffer[_length++] = (value >> 8) & 0xFF;
    _buffer[_length++] = value & 0xFF;
  }

  /// Adds a 16-bit unsigned integer in big-endian format.
  ///
  /// #### Parameters
  /// - `value` - U16 value to encode
  ///
  @pragma('vm:prefer-inline')
  void addU16(int value) {
    _ensureCapacity(2);
    _buffer[_length++] = (value >> 8) & 0xFF;
    _buffer[_length++] = value & 0xFF;
  }

  /// Adds an 8-bit unsigned integer.
  ///
  /// #### Parameters
  /// - `value` - U8 value to encode
  ///
  @pragma('vm:prefer-inline')
  void addU8(int value) {
    addByte(value);
  }

  /// Adds length prefix (4 bytes) followed by data.
  ///
  /// #### Parameters
  /// - `data` - Data to length-prefix
  ///
  void addLengthPrefixed(Uint8List data) {
    addU32(data.length);
    addBytes(data);
  }

  /// Ensures buffer has capacity for N more bytes.
  void _ensureCapacity(int additionalBytes) {
    final int requiredCapacity = _length + additionalBytes;
    if (requiredCapacity <= _buffer.length) return;

    final int newCapacity = _buffer.length * 2;
    final int targetCapacity = newCapacity > requiredCapacity
        ? newCapacity
        : requiredCapacity + (_buffer.length ~/ 2);

    final Uint8List newBuffer = Uint8List(targetCapacity);
    newBuffer.setRange(0, _length, _buffer);
    _buffer = newBuffer;
  }

  /// Returns the built buffer as Uint8List.
  ///
  /// #### Returns
  /// Uint8List containing all added bytes (exact size)
  Uint8List toBytes() {
    if (_length == 0) return BinaryCodecUtils.emptyBuffer;
    return Uint8List.sublistView(_buffer, 0, _length);
  }

  /// Returns the built buffer as a view without copying.
  ///
  /// #### Returns
  /// Uint8List view of the internal buffer
  Uint8List toView() {
    if (_length == 0) return BinaryCodecUtils.emptyBuffer;
    return Uint8List.view(_buffer.buffer, 0, _length);
  }

  /// Clears all data from the builder (keeps allocated capacity).
  ///
  void clear() {
    _length = 0;
  }

  /// Resets the builder to initial state with new capacity.
  ///
  /// #### Parameters
  /// - `newCapacity` - New initial capacity (optional)
  ///
  void reset({int? newCapacity}) {
    if (newCapacity != null) {
      _buffer = Uint8List(newCapacity);
    }
    _length = 0;
  }

  @override
  String toString() =>
      'BinaryBuilder(length: $_length, capacity: ${_buffer.length})';
}
