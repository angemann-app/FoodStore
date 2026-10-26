import 'dart:convert';

import 'freezer_compartment.dart';

enum HouseholdRole {
  host,
  member;

  String get label =>
      this == HouseholdRole.host ? 'Host / Admin (max. 2)' : 'Familienmitglied';
}

class NostrUserProfile {
  final String pubkey;
  final String privkey;
  final String displayName;
  final String avatarColorHex;

  const NostrUserProfile({
    required this.pubkey,
    required this.privkey,
    required this.displayName,
    required this.avatarColorHex,
  });

  String get shortPubkey {
    if (pubkey.length < 12) return pubkey;
    return 'npub1${pubkey.substring(0, 6)}…${pubkey.substring(pubkey.length - 6)}';
  }

  NostrUserProfile copyWith({
    String? pubkey,
    String? privkey,
    String? displayName,
    String? avatarColorHex,
  }) {
    return NostrUserProfile(
      pubkey: pubkey ?? this.pubkey,
      privkey: privkey ?? this.privkey,
      displayName: displayName ?? this.displayName,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
    );
  }

  Map<String, dynamic> toJson() => {
        'pubkey': pubkey,
        'privkey': privkey,
        'displayName': displayName,
        'avatarColorHex': avatarColorHex,
      };

  factory NostrUserProfile.fromJson(Map<String, dynamic> json) {
    return NostrUserProfile(
      pubkey: json['pubkey']?.toString() ?? '',
      privkey: json['privkey']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Benutzer',
      avatarColorHex: json['avatarColorHex']?.toString() ?? '#0288D1',
    );
  }
}

class HouseholdMember {
  final String pubkey;
  final String displayName;
  final HouseholdRole role;
  final String colorHex;
  final DateTime addedAt;
  final String addedByPubkey;
  final bool isActive;

  const HouseholdMember({
    required this.pubkey,
    required this.displayName,
    required this.role,
    required this.colorHex,
    required this.addedAt,
    required this.addedByPubkey,
    this.isActive = true,
  });

  String get shortPubkey {
    if (pubkey.length < 12) return pubkey;
    return 'npub1${pubkey.substring(0, 6)}…${pubkey.substring(pubkey.length - 4)}';
  }

  HouseholdMember copyWith({
    String? pubkey,
    String? displayName,
    HouseholdRole? role,
    String? colorHex,
    DateTime? addedAt,
    String? addedByPubkey,
    bool? isActive,
  }) {
    return HouseholdMember(
      pubkey: pubkey ?? this.pubkey,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      colorHex: colorHex ?? this.colorHex,
      addedAt: addedAt ?? this.addedAt,
      addedByPubkey: addedByPubkey ?? this.addedByPubkey,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'pubkey': pubkey,
        'displayName': displayName,
        'role': role.name,
        'colorHex': colorHex,
        'addedAt': addedAt.toIso8601String(),
        'addedByPubkey': addedByPubkey,
        'isActive': isActive,
      };

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      pubkey: json['pubkey']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Familienmitglied',
      role: json['role'] == 'host' ? HouseholdRole.host : HouseholdRole.member,
      colorHex: json['colorHex']?.toString() ?? '#0288D1',
      addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? '') ?? DateTime.now(),
      addedByPubkey: json['addedByPubkey']?.toString() ?? '',
      isActive: json['isActive'] != false,
    );
  }
}

class R2Config {
  final String accountId;
  final String bucketName;
  final String accessKeyId;
  final String secretAccessKey;
  final String publicBaseUrl;
  final bool shareWithHousehold;

  const R2Config({
    this.accountId = '',
    this.bucketName = '',
    this.accessKeyId = '',
    this.secretAccessKey = '',
    this.publicBaseUrl = '',
    this.shareWithHousehold = true,
  });

  bool get isConfigured =>
      accountId.trim().isNotEmpty &&
      bucketName.trim().isNotEmpty &&
      accessKeyId.trim().isNotEmpty &&
      secretAccessKey.trim().isNotEmpty;

  String get endpointHost => '${accountId.trim()}.r2.cloudflarestorage.com';

  String resolvePublicUrl(String objectKey) {
    final base = publicBaseUrl.trim();
    if (base.isNotEmpty) {
      final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      return '$cleanBase/$objectKey';
    }
    return 'https://$endpointHost/${bucketName.trim()}/$objectKey';
  }

  R2Config copyWith({
    String? accountId,
    String? bucketName,
    String? accessKeyId,
    String? secretAccessKey,
    String? publicBaseUrl,
    bool? shareWithHousehold,
  }) {
    return R2Config(
      accountId: accountId ?? this.accountId,
      bucketName: bucketName ?? this.bucketName,
      accessKeyId: accessKeyId ?? this.accessKeyId,
      secretAccessKey: secretAccessKey ?? this.secretAccessKey,
      publicBaseUrl: publicBaseUrl ?? this.publicBaseUrl,
      shareWithHousehold: shareWithHousehold ?? this.shareWithHousehold,
    );
  }

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'bucketName': bucketName,
        'accessKeyId': accessKeyId,
        'secretAccessKey': secretAccessKey,
        'publicBaseUrl': publicBaseUrl,
        'shareWithHousehold': shareWithHousehold,
      };

  factory R2Config.fromJson(Map<String, dynamic> json) {
    return R2Config(
      accountId: json['accountId']?.toString() ?? '',
      bucketName: json['bucketName']?.toString() ?? '',
      accessKeyId: json['accessKeyId']?.toString() ?? '',
      secretAccessKey: json['secretAccessKey']?.toString() ?? '',
      publicBaseUrl: json['publicBaseUrl']?.toString() ?? '',
      shareWithHousehold: json['shareWithHousehold'] != false,
    );
  }
}

class HouseholdConfig {
  /// Maximal 2 Personen dürfen gleichzeitig den Admin-/Host-Posten bekleiden.
  static const int maxAdmins = 2;

  final String householdId;
  final String householdName;
  final String householdPubkey;
  final String householdPrivkey;
  final String hostPubkey;
  final String hostName;
  final List<String> adminPubkeys;
  final List<HouseholdMember> members;
  final List<String> relays;
  final R2Config r2Config;
  final Map<String, CompartmentCustomLabel> compartmentLabels;

  const HouseholdConfig({
    required this.householdId,
    required this.householdName,
    required this.householdPubkey,
    required this.householdPrivkey,
    required this.hostPubkey,
    required this.hostName,
    this.adminPubkeys = const [],
    required this.members,
    required this.relays,
    this.r2Config = const R2Config(),
    this.compartmentLabels = const {},
  });

  /// Alle aktiven Admins/Hosts (max. 2 Personen).
  List<String> get effectiveAdminPubkeys {
    final set = <String>{};
    if (hostPubkey.isNotEmpty) set.add(hostPubkey);
    for (final pk in adminPubkeys) {
      if (pk.isNotEmpty && set.length < maxAdmins) {
        set.add(pk);
      }
    }
    for (final m in members) {
      if (m.isActive && m.role == HouseholdRole.host && set.length < maxAdmins) {
        set.add(m.pubkey);
      }
    }
    return set.toList();
  }

  /// Prüft, ob dieser Benutzer einer der (maximal 2) Hosts/Admins ist.
  bool isHost(String userPubkey) => effectiveAdminPubkeys.contains(userPubkey);

  /// Wie viele der 2 Admin-Plätze aktuell belegt sind.
  int get adminCount => effectiveAdminPubkeys.length;

  /// Ob noch der 2. Admin-Posten frei ist.
  bool get hasOpenAdminSlot => adminCount < maxAdmins;

  bool isMember(String userPubkey) {
    if (isHost(userPubkey)) return true;
    return members.any((m) => m.pubkey == userPubkey && m.isActive);
  }

  List<HouseholdMember> get activeMembers =>
      members.where((m) => m.isActive).toList();

  List<HouseholdMember> get activeAdmins =>
      members.where((m) => m.isActive && isHost(m.pubkey)).toList();

  HouseholdConfig copyWith({
    String? householdId,
    String? householdName,
    String? householdPubkey,
    String? householdPrivkey,
    String? hostPubkey,
    String? hostName,
    List<String>? adminPubkeys,
    List<HouseholdMember>? members,
    List<String>? relays,
    R2Config? r2Config,
    Map<String, CompartmentCustomLabel>? compartmentLabels,
  }) {
    return HouseholdConfig(
      householdId: householdId ?? this.householdId,
      householdName: householdName ?? this.householdName,
      householdPubkey: householdPubkey ?? this.householdPubkey,
      householdPrivkey: householdPrivkey ?? this.householdPrivkey,
      hostPubkey: hostPubkey ?? this.hostPubkey,
      hostName: hostName ?? this.hostName,
      adminPubkeys: adminPubkeys ?? this.adminPubkeys,
      members: members ?? this.members,
      relays: relays ?? this.relays,
      r2Config: r2Config ?? this.r2Config,
      compartmentLabels: compartmentLabels ?? this.compartmentLabels,
    );
  }

  /// Erzeugt einen Einladungs-Code / QR-Code von einem der 2 Admins für ein Familienmitglied
  String toInviteQrPayload({
    String? preAssignedMemberName,
    String? preAssignedMemberPrivkey,
    String? preAssignedMemberPubkey,
    HouseholdRole assignedRole = HouseholdRole.member,
  }) {
    final map = <String, dynamic>{
      'type': 'eiszeit_household_invite_v1',
      'householdId': householdId,
      'householdName': householdName,
      'householdPubkey': householdPubkey,
      'householdPrivkey': householdPrivkey,
      'hostPubkey': hostPubkey,
      'hostName': hostName,
      'adminPubkeys': effectiveAdminPubkeys,
      'members': members.map((m) => m.toJson()).toList(),
      'relays': relays,
      'assignedRole': assignedRole.name,
      'compartmentLabels': compartmentLabels.map((k, v) => MapEntry(k, v.toJson())),
      if (r2Config.isConfigured && r2Config.shareWithHousehold)
        'r2Config': r2Config.toJson(),
    };
    if (preAssignedMemberName != null) {
      map['assignedMemberName'] = preAssignedMemberName;
    }
    if (preAssignedMemberPrivkey != null) {
      map['assignedMemberPrivkey'] = preAssignedMemberPrivkey;
    }
    if (preAssignedMemberPubkey != null) {
      map['assignedMemberPubkey'] = preAssignedMemberPubkey;
    }
    return 'eiszeit://${base64UrlEncode(utf8.encode(jsonEncode(map)))}';
  }

  static Map<String, dynamic>? parseInviteQrPayload(String raw) {
    try {
      String encoded = raw.trim();
      if (encoded.startsWith('eiszeit://')) {
        encoded = encoded.substring('eiszeit://'.length);
      }
      final decoded = utf8.decode(base64Url.decode(encoded));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      if (map['type'] != 'eiszeit_household_invite_v1') return null;
      return map;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'householdId': householdId,
        'householdName': householdName,
        'householdPubkey': householdPubkey,
        'householdPrivkey': householdPrivkey,
        'hostPubkey': hostPubkey,
        'hostName': hostName,
        'adminPubkeys': effectiveAdminPubkeys,
        'members': members.map((m) => m.toJson()).toList(),
        'relays': relays,
        'r2Config': r2Config.toJson(),
        'compartmentLabels': compartmentLabels.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory HouseholdConfig.fromJson(Map<String, dynamic> json) {
    final membersList = (json['members'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(HouseholdMember.fromJson)
        .toList();
    final relaysList = (json['relays'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final adminsList = (json['adminPubkeys'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    final labelsMap = <String, CompartmentCustomLabel>{};
    if (json['compartmentLabels'] is Map<String, dynamic>) {
      final rawLabels = json['compartmentLabels'] as Map<String, dynamic>;
      for (final entry in rawLabels.entries) {
        if (entry.value is Map<String, dynamic>) {
          labelsMap[entry.key] = CompartmentCustomLabel.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    return HouseholdConfig(
      householdId: json['householdId']?.toString() ?? 'default',
      householdName: json['householdName']?.toString() ?? 'Siemens NoFrost Gefrierschrank',
      householdPubkey: json['householdPubkey']?.toString() ?? '',
      householdPrivkey: json['householdPrivkey']?.toString() ?? '',
      hostPubkey: json['hostPubkey']?.toString() ?? '',
      hostName: json['hostName']?.toString() ?? 'Host',
      adminPubkeys: adminsList,
      members: membersList,
      relays: relaysList.isNotEmpty
          ? relaysList
          : const [
              'wss://relay.damus.io',
              'wss://nos.lol',
              'wss://relay.primal.net',
            ],
      r2Config: json['r2Config'] is Map<String, dynamic>
          ? R2Config.fromJson(json['r2Config'] as Map<String, dynamic>)
          : const R2Config(),
      compartmentLabels: labelsMap,
    );
  }
}

enum TransactionType {
  checkIn,
  checkOut,
  quantityChange,
  moveCompartment,
  icePackToggle,
  compartmentLabeled,
  memberAdded,
  memberRemoved,
  adminChanged;

  String get label {
    switch (this) {
      case TransactionType.checkIn:
        return 'Eingelagert';
      case TransactionType.checkOut:
        return 'Entnommen';
      case TransactionType.quantityChange:
        return 'Menge angepasst';
      case TransactionType.moveCompartment:
        return 'Umgeräumt';
      case TransactionType.icePackToggle:
        return 'Kühlakku-Status';
      case TransactionType.compartmentLabeled:
        return 'Schublade beschriftet';
      case TransactionType.memberAdded:
        return 'Mitglied eingeladen';
      case TransactionType.memberRemoved:
        return 'Mitglied entfernt';
      case TransactionType.adminChanged:
        return 'Admin-Rolle geändert';
    }
  }
}

class InventoryTransaction {
  final String id;
  final TransactionType type;
  final String itemId;
  final String itemName;
  final String compartmentId;
  final String? targetCompartmentId;
  final double quantityDelta;
  final String unit;
  final String actorPubkey;
  final String actorName;
  final DateTime timestamp;
  final String? note;
  final String? nostrEventId;

  const InventoryTransaction({
    required this.id,
    required this.type,
    required this.itemId,
    required this.itemName,
    required this.compartmentId,
    this.targetCompartmentId,
    required this.quantityDelta,
    required this.unit,
    required this.actorPubkey,
    required this.actorName,
    required this.timestamp,
    this.note,
    this.nostrEventId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'itemId': itemId,
        'itemName': itemName,
        'compartmentId': compartmentId,
        if (targetCompartmentId != null) 'targetCompartmentId': targetCompartmentId,
        'quantityDelta': quantityDelta,
        'unit': unit,
        'actorPubkey': actorPubkey,
        'actorName': actorName,
        'timestamp': timestamp.toIso8601String(),
        if (note != null) 'note': note,
        if (nostrEventId != null) 'nostrEventId': nostrEventId,
      };

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type']?.toString() ?? 'checkIn';
    final txType = TransactionType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TransactionType.checkIn,
    );
    return InventoryTransaction(
      id: json['id']?.toString() ?? '',
      type: txType,
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      compartmentId: json['compartmentId']?.toString() ?? 'drawer_1',
      targetCompartmentId: json['targetCompartmentId']?.toString(),
      quantityDelta: (json['quantityDelta'] is num)
          ? (json['quantityDelta'] as num).toDouble()
          : double.tryParse(json['quantityDelta']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString() ?? 'Stück',
      actorPubkey: json['actorPubkey']?.toString() ?? '',
      actorName: json['actorName']?.toString() ?? 'Familienmitglied',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      note: json['note']?.toString(),
      nostrEventId: json['nostrEventId']?.toString(),
    );
  }
}
