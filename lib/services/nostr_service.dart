import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/freezer_item.dart';
import '../models/nostr_models.dart';
import 'nostr_crypto.dart';

enum RelayConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class NostrRelayStatus {
  final String url;
  final RelayConnectionState state;
  final String? lastError;
  final int eventsReceived;
  final int eventsPublished;

  const NostrRelayStatus({
    required this.url,
    required this.state,
    this.lastError,
    this.eventsReceived = 0,
    this.eventsPublished = 0,
  });

  NostrRelayStatus copyWith({
    RelayConnectionState? state,
    String? lastError,
    int? eventsReceived,
    int? eventsPublished,
  }) {
    return NostrRelayStatus(
      url: url,
      state: state ?? this.state,
      lastError: lastError,
      eventsReceived: eventsReceived ?? this.eventsReceived,
      eventsPublished: eventsPublished ?? this.eventsPublished,
    );
  }
}

typedef SnapshotReceivedCallback = void Function({
  required List<FreezerItem> items,
  required HouseholdConfig updatedHousehold,
  required String senderPubkey,
  required DateTime timestamp,
});

typedef TransactionReceivedCallback = void Function(InventoryTransaction transaction);

typedef JoinAnnouncementCallback = void Function({
  required String memberPubkey,
  required String memberName,
  required String colorHex,
});

class NostrService {
  static const int kindAppSpecificData = 30078; // NIP-78

  final Map<String, WebSocketChannel> _channels = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, NostrRelayStatus> _relayStatuses = {};
  final Set<String> _seenEventIds = {};

  SnapshotReceivedCallback? onSnapshotReceived;
  TransactionReceivedCallback? onTransactionReceived;
  JoinAnnouncementCallback? onJoinAnnouncement;
  VoidCallback? onStatusChanged;

  Map<String, NostrRelayStatus> get relayStatuses => Map.unmodifiable(_relayStatuses);

  int get connectedCount => _relayStatuses.values
      .where((s) => s.state == RelayConnectionState.connected)
      .length;

  /// Verbindet zu allen konfigurierten Relays des Haushalts und abonniert Änderungen.
  Future<void> connectToRelays(HouseholdConfig household) async {
    await disconnectAll();

    for (final url in household.relays) {
      final cleanUrl = url.trim();
      if (cleanUrl.isEmpty) continue;
      _connectSingleRelay(cleanUrl, household);
    }
  }

  void _connectSingleRelay(String url, HouseholdConfig household) {
    _relayStatuses[url] = NostrRelayStatus(
      url: url,
      state: RelayConnectionState.connecting,
    );
    onStatusChanged?.call();

    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channels[url] = channel;

      final subId = 'ez_${household.householdId.substring(0, household.householdId.length.clamp(0, 10))}';
      final reqFilter = <String, dynamic>{
        'kinds': [kindAppSpecificData],
        '#p': [household.householdPubkey],
        'limit': 50,
      };

      // Sende NIP-01 REQ
      channel.sink.add(jsonEncode(['REQ', subId, reqFilter]));

      _relayStatuses[url] = NostrRelayStatus(
        url: url,
        state: RelayConnectionState.connected,
      );
      onStatusChanged?.call();

      final sub = channel.stream.listen(
        (dynamic rawMessage) {
          _handleRelayMessage(url, rawMessage.toString(), household);
        },
        onError: (Object error) {
          _relayStatuses[url] = (_relayStatuses[url] ??
                  NostrRelayStatus(url: url, state: RelayConnectionState.error))
              .copyWith(
            state: RelayConnectionState.error,
            lastError: error.toString(),
          );
          onStatusChanged?.call();
        },
        onDone: () {
          final current = _relayStatuses[url];
          if (current != null && current.state != RelayConnectionState.error) {
            _relayStatuses[url] = current.copyWith(
              state: RelayConnectionState.disconnected,
            );
            onStatusChanged?.call();
          }
        },
      );
      _subscriptions[url] = sub;
    } catch (e) {
      _relayStatuses[url] = NostrRelayStatus(
        url: url,
        state: RelayConnectionState.error,
        lastError: e.toString(),
      );
      onStatusChanged?.call();
    }
  }

  void _handleRelayMessage(String relayUrl, String rawMessage, HouseholdConfig household) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! List || decoded.isEmpty) return;

      final msgType = decoded[0]?.toString();
      if (msgType != 'EVENT' || decoded.length < 3) return;

      final eventMap = decoded[2];
      if (eventMap is! Map<String, dynamic>) return;

      final eventId = eventMap['id']?.toString() ?? '';
      final senderPubkey = eventMap['pubkey']?.toString() ?? '';
      final sig = eventMap['sig']?.toString() ?? '';
      final content = eventMap['content']?.toString() ?? '';
      final createdAt = (eventMap['created_at'] is int)
          ? eventMap['created_at'] as int
          : int.tryParse(eventMap['created_at']?.toString() ?? '0') ?? 0;

      if (eventId.isEmpty || _seenEventIds.contains(eventId)) return;

      // Verifiziere BIP-340 Schnorr Signatur
      if (!NostrCrypto.verifySignature(eventId, senderPubkey, sig)) {
        return;
      }

      _seenEventIds.add(eventId);
      final currentStatus = _relayStatuses[relayUrl];
      if (currentStatus != null) {
        _relayStatuses[relayUrl] = currentStatus.copyWith(
          eventsReceived: currentStatus.eventsReceived + 1,
        );
        onStatusChanged?.call();
      }

      // Entschlüssele Haushalts-Payload
      final decryptedJson = NostrCrypto.decryptFromHousehold(
        content,
        household.householdPrivkey,
      );
      if (decryptedJson == null) return;

      final payload = jsonDecode(decryptedJson) as Map<String, dynamic>;
      final payloadType = payload['payloadType']?.toString() ?? '';

      if (payloadType == 'join_announcement') {
        final memberName = payload['memberName']?.toString() ?? 'Familienmitglied';
        final colorHex = payload['colorHex']?.toString() ?? '#0288D1';
        onJoinAnnouncement?.call(
          memberPubkey: senderPubkey,
          memberName: memberName,
          colorHex: colorHex,
        );
        return;
      }

      // Prüfe ob der Absender Mitglied oder einer der 2 Hosts/Admins ist
      if (!household.isMember(senderPubkey)) {
        return;
      }

      if (payloadType == 'snapshot') {
        final itemsRaw = payload['items'] as List<dynamic>? ?? [];
        final items = itemsRaw
            .whereType<Map<String, dynamic>>()
            .map(FreezerItem.fromJson)
            .toList();

        HouseholdConfig updatedHousehold = household;
        if (payload['household'] is Map<String, dynamic>) {
          final incomingHousehold = HouseholdConfig.fromJson(
            payload['household'] as Map<String, dynamic>,
          );
          // Nur die (max. 2) Hosts/Admins dürfen die Mitgliederliste / Admin-Rollen ändern
          if (household.isHost(senderPubkey)) {
            updatedHousehold = incomingHousehold;
          }
        }

        onSnapshotReceived?.call(
          items: items,
          updatedHousehold: updatedHousehold,
          senderPubkey: senderPubkey,
          timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
        );
      } else if (payloadType == 'transaction') {
        final txMap = payload['transaction'];
        if (txMap is Map<String, dynamic>) {
          final tx = InventoryTransaction.fromJson(txMap);
          onTransactionReceived?.call(tx);
        }
      }
    } catch (_) {
      // Ignoriere fehlerhafte Fremd-Events
    }
  }

  /// Publiziert den aktuellen Gefrierschrank-Bestand + Haushalts-Mitgliederliste verschlüsselt über Nostr.
  Future<String?> publishSnapshot({
    required NostrUserProfile author,
    required HouseholdConfig household,
    required List<FreezerItem> items,
  }) async {
    final payloadMap = {
      'payloadType': 'snapshot',
      'householdId': household.householdId,
      'updatedBy': author.pubkey,
      'updatedByName': author.displayName,
      'household': household.toJson(),
      'items': items.map((i) => i.toJson(includeLocalPath: false)).toList(),
    };

    final encryptedContent = NostrCrypto.encryptForHousehold(
      jsonEncode(payloadMap),
      household.householdPrivkey,
    );

    final tags = <List<String>>[
      ['d', 'eiszeit_snapshot_${household.householdId}'],
      ['p', household.householdPubkey],
      ['client', 'Eiszeit'],
    ];

    return _signAndPublish(
      author: author,
      kind: kindAppSpecificData,
      tags: tags,
      content: encryptedContent,
    );
  }

  /// Publiziert einen einzelnen Ein-/Auslagerungs-Vorgang für das Live-Aktivitäts-Log.
  Future<String?> publishTransaction({
    required NostrUserProfile author,
    required HouseholdConfig household,
    required InventoryTransaction transaction,
  }) async {
    final payloadMap = {
      'payloadType': 'transaction',
      'householdId': household.householdId,
      'transaction': transaction.toJson(),
    };

    final encryptedContent = NostrCrypto.encryptForHousehold(
      jsonEncode(payloadMap),
      household.householdPrivkey,
    );

    final tags = <List<String>>[
      ['d', 'eiszeit_tx_${transaction.id}'],
      ['p', household.householdPubkey],
      ['client', 'Eiszeit'],
    ];

    return _signAndPublish(
      author: author,
      kind: kindAppSpecificData,
      tags: tags,
      content: encryptedContent,
    );
  }

  /// Sendet eine Beitritts-Meldung an die Hosts/Admins, wenn ein eingeladenes Mitglied den QR-Code scannt.
  Future<String?> publishJoinAnnouncement({
    required NostrUserProfile memberProfile,
    required HouseholdConfig household,
  }) async {
    final payloadMap = {
      'payloadType': 'join_announcement',
      'householdId': household.householdId,
      'memberPubkey': memberProfile.pubkey,
      'memberName': memberProfile.displayName,
      'colorHex': memberProfile.avatarColorHex,
    };

    final encryptedContent = NostrCrypto.encryptForHousehold(
      jsonEncode(payloadMap),
      household.householdPrivkey,
    );

    final tags = <List<String>>[
      ['d', 'eiszeit_join_${memberProfile.pubkey.substring(0, 12)}'],
      ['p', household.householdPubkey],
      ['client', 'Eiszeit'],
    ];

    return _signAndPublish(
      author: memberProfile,
      kind: kindAppSpecificData,
      tags: tags,
      content: encryptedContent,
    );
  }

  Future<String?> _signAndPublish({
    required NostrUserProfile author,
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) async {
    try {
      final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final eventId = NostrCrypto.computeEventId(
        pubkey: author.pubkey,
        createdAt: createdAt,
        kind: kind,
        tags: tags,
        content: content,
      );
      final sig = NostrCrypto.signEventId(eventId, author.privkey);

      _seenEventIds.add(eventId);

      final eventObject = {
        'id': eventId,
        'pubkey': author.pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig,
      };

      final wireMessage = jsonEncode(['EVENT', eventObject]);

      for (final entry in _channels.entries) {
        final url = entry.key;
        final status = _relayStatuses[url];
        if (status?.state == RelayConnectionState.connected) {
          try {
            entry.value.sink.add(wireMessage);
            _relayStatuses[url] = status!.copyWith(
              eventsPublished: status.eventsPublished + 1,
            );
          } catch (_) {}
        }
      }
      onStatusChanged?.call();
      return eventId;
    } catch (_) {
      return null;
    }
  }

  Future<void> disconnectAll() async {
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();

    for (final ch in _channels.values) {
      try {
        await ch.sink.close();
      } catch (_) {}
    }
    _channels.clear();
  }
}
