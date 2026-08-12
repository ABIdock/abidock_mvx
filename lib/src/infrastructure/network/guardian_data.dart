/// Guardian data DTO returned by the `getGuardianData` network endpoint.
///
/// The endpoint reports
/// `{ guarded: bool, activeGuardian?: Guardian, pendingGuardian?: Guardian }`
/// where each `Guardian` is `{ address, activationEpoch, serviceUID }`.
library;

import 'package:meta/meta.dart';

import '../../core/address.dart';
import '../../utils/helpers.dart';

/// Single guardian entry exposed by `getGuardianData`.
///
/// #### Example
/// ```dart
/// final g = Guardian.fromHttpResponse(<String, dynamic>{
///   'address': 'erd1...',
///   'activationEpoch': 42,
///   'serviceUID': 'TCS',
/// });
/// print(g.address.bech32);
/// ```
@immutable
class Guardian {
  /// Creates a `Guardian`.
  ///
  /// #### Parameters
  /// - `address` - Guardian address.
  /// - `activationEpoch` - Epoch in which the guardian becomes (or became) active.
  /// - `serviceUid` - Guardian-service identifier (e.g. `"TCS"`).
  const Guardian({
    required this.address,
    required this.activationEpoch,
    required this.serviceUid,
  });

  /// Guardian address.
  final Address address;

  /// Activation epoch.
  final int activationEpoch;

  /// Guardian-service identifier.
  final String serviceUid;

  /// Parses a `Guardian` from a Gateway or API JSON object.
  ///
  /// Accepts both `serviceUID` (Gateway) and `serviceUid` (API) keys, and
  /// tolerates `activationEpoch` arriving as either `int` or `String`.
  ///
  /// #### Parameters
  /// - `data` - JSON object describing one guardian.
  ///
  /// #### Returns
  /// `Guardian` - Parsed instance.
  factory Guardian.fromHttpResponse(Map<String, dynamic> data) {
    final dynamic rawEpoch = data['activationEpoch'];
    final int epoch = rawEpoch is int
        ? rawEpoch
        : int.parse(rawEpoch.toString());
    final String serviceUid =
        optionalAs<String>(data['serviceUID'], 'serviceUID') ??
        optionalAs<String>(data['serviceUid'], 'serviceUid') ??
        '';
    return Guardian(
      address: Address.fromBech32(
        requireAs<String>(data['address'], 'address'),
      ),
      activationEpoch: epoch,
      serviceUid: serviceUid,
    );
  }

  @override
  String toString() =>
      'Guardian(address: ${address.bech32}, '
      'activationEpoch: $activationEpoch, serviceUid: $serviceUid)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Guardian &&
        other.address == address &&
        other.activationEpoch == activationEpoch &&
        other.serviceUid == serviceUid;
  }

  @override
  int get hashCode => Object.hash(address, activationEpoch, serviceUid);
}

/// Full response payload of the `getGuardianData` endpoint.
///
/// #### Example
/// ```dart
/// final data = GuardianData.fromHttpResponse(<String, dynamic>{
///   'guarded': true,
///   'activeGuardian': <String, dynamic>{
///     'address': 'erd1...',
///     'activationEpoch': 42,
///     'serviceUID': 'TCS',
///   },
/// });
/// print(data.guarded);
/// ```
@immutable
class GuardianData {
  /// Creates a `GuardianData`.
  ///
  /// #### Parameters
  /// - `guarded` - Whether the account is currently guarded.
  /// - `activeGuardian` - Active guardian, if any.
  /// - `pendingGuardian` - Pending guardian (queued activation), if any.
  const GuardianData({
    required this.guarded,
    this.activeGuardian,
    this.pendingGuardian,
  });

  /// Whether the account is currently guarded.
  final bool guarded;

  /// Active guardian, if any.
  final Guardian? activeGuardian;

  /// Pending guardian (queued activation), if any.
  final Guardian? pendingGuardian;

  /// Parses a `GuardianData` from a Gateway or API JSON payload.
  ///
  /// Both providers expose the same nested object shape under the
  /// `guardianData` key; this factory accepts either the bare `guardianData`
  /// object or a wrapper containing it.
  ///
  /// #### Parameters
  /// - `data` - JSON object with `guarded` / `activeGuardian` / `pendingGuardian`.
  ///
  /// #### Returns
  /// `GuardianData` - Parsed instance.
  factory GuardianData.fromHttpResponse(Map<String, dynamic> data) {
    final Map<String, dynamic> payload =
        optionalAs<Map<String, dynamic>>(
          data['guardianData'],
          'guardianData',
        ) ??
        data;

    final dynamic activeRaw = payload['activeGuardian'];
    final dynamic pendingRaw = payload['pendingGuardian'];

    Guardian? parseOptional(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        if (raw.isEmpty) {
          return null;
        }
        final dynamic address = raw['address'];
        if (address == null || (address is String && address.isEmpty)) {
          return null;
        }
        return Guardian.fromHttpResponse(raw);
      }
      return null;
    }

    return GuardianData(
      guarded: payload['guarded'] == true,
      activeGuardian: parseOptional(activeRaw),
      pendingGuardian: parseOptional(pendingRaw),
    );
  }

  @override
  String toString() =>
      'GuardianData(guarded: $guarded, '
      'activeGuardian: $activeGuardian, pendingGuardian: $pendingGuardian)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GuardianData &&
        other.guarded == guarded &&
        other.activeGuardian == activeGuardian &&
        other.pendingGuardian == pendingGuardian;
  }

  @override
  int get hashCode => Object.hash(guarded, activeGuardian, pendingGuardian);
}
