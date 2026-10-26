import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/freezer_compartment.dart';
import '../models/freezer_item.dart';
import '../models/nostr_models.dart';
import 'nostr_crypto.dart';
import 'nostr_service.dart';
import 'r2_storage_service.dart';

class PendingMemberInvite {
  final HouseholdMember member;
  final String generatedPrivkey;
  final String qrPayload;

  const PendingMemberInvite({
    required this.member,
    required this.generatedPrivkey,
    required this.qrPayload,
  });
}

class AppState extends ChangeNotifier {
  static const String _prefProfileKey = 'eiszeit_user_profile_v1';
  static const String _prefHouseholdKey = 'eiszeit_household_config_v1';
  static const String _prefItemsKey = 'eiszeit_freezer_items_v1';
  static const String _prefTransactionsKey = 'eiszeit_transactions_v1';

  final NostrService nostrService = NostrService();

  late NostrUserProfile _currentUser;
  late HouseholdConfig _household;
  List<FreezerItem> _items = [];
  List<InventoryTransaction> _transactions = [];
  bool _isInitialized = false;
  bool _isMigratingR2 = false;
  String? _lastSyncMessage;

  NostrUserProfile get currentUser => _currentUser;
  HouseholdConfig get household => _household;
  List<FreezerItem> get items => List.unmodifiable(_items);
  List<InventoryTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isInitialized => _isInitialized;
  bool get isMigratingR2 => _isMigratingR2;
  String? get lastSyncMessage => _lastSyncMessage;

  /// Ist der aktuelle Benutzer einer der (maximal 2) Hosts/Admins?
  bool get isCurrentUserHost => _household.isHost(_currentUser.pubkey);

  /// Ist der aktuelle Benutzer in der Familienmitglieder-Liste freigeschaltet?
  bool get isCurrentUserAuthorized => _household.isMember(_currentUser.pubkey);

  /// Artikel, die bald ablaufen oder bereits überfällig sind (Gefrierbrand-Warnung)
  List<FreezerItem> get expiringOrExpiredItems {
    final list = _items
        .where((i) => i.freshnessStatus != FreshnessStatus.fresh)
        .toList();
    list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return list;
  }

  /// Anzahl der Bilder, die noch lokal/als Vorschau vorliegen und später auf Cloudflare R2 geladen werden können
  int get pendingR2UploadCount => _items.where((i) => i.needsR2Upload).length;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    // 1. Lade oder erstelle Benutzerprofil
    final profileJson = prefs.getString(_prefProfileKey);
    if (profileJson != null) {
      _currentUser = NostrUserProfile.fromJson(
        jsonDecode(profileJson) as Map<String, dynamic>,
      );
    } else {
      final keys = NostrCrypto.generateKeyPair();
      _currentUser = NostrUserProfile(
        pubkey: keys['pubkey']!,
        privkey: keys['privkey']!,
        displayName: 'Holger',
        avatarColorHex: '#0288D1',
      );
      await prefs.setString(_prefProfileKey, jsonEncode(_currentUser.toJson()));
    }

    // 2. Lade oder erstelle Haushalt (mit Host = Ersteller; bis zu 2 Admins möglich)
    final householdJson = prefs.getString(_prefHouseholdKey);
    if (householdJson != null) {
      _household = HouseholdConfig.fromJson(
        jsonDecode(householdJson) as Map<String, dynamic>,
      );
    } else {
      final householdKeys = NostrCrypto.generateKeyPair();
      final hostMember = HouseholdMember(
        pubkey: _currentUser.pubkey,
        displayName: _currentUser.displayName,
        role: HouseholdRole.host,
        colorHex: _currentUser.avatarColorHex,
        addedAt: DateTime.now(),
        addedByPubkey: _currentUser.pubkey,
      );
      _household = HouseholdConfig(
        householdId: 'siemens_nofrost_${householdKeys['pubkey']!.substring(0, 8)}',
        householdName: 'Siemens NoFrost Gefrierschrank',
        householdPubkey: householdKeys['pubkey']!,
        householdPrivkey: householdKeys['privkey']!,
        hostPubkey: _currentUser.pubkey,
        hostName: _currentUser.displayName,
        adminPubkeys: [_currentUser.pubkey],
        members: [hostMember],
        relays: const [
          'wss://relay.damus.io',
          'wss://nos.lol',
          'wss://relay.primal.net',
        ],
      );
      await prefs.setString(_prefHouseholdKey, jsonEncode(_household.toJson()));
    }

    // 3. Lade oder initialisiere Gefrierschrank-Bestand (passend zum Foto)
    final itemsJson = prefs.getString(_prefItemsKey);
    if (itemsJson != null) {
      final rawList = jsonDecode(itemsJson) as List<dynamic>;
      _items = rawList
          .whereType<Map<String, dynamic>>()
          .map(FreezerItem.fromJson)
          .toList();
    } else {
      _items = _createInitialPhotoInventory();
      await _saveItemsToPrefs(prefs);
    }

    // 4. Lade oder initialisiere Aktivitäts-Historie
    final txJson = prefs.getString(_prefTransactionsKey);
    if (txJson != null) {
      final rawTx = jsonDecode(txJson) as List<dynamic>;
      _transactions = rawTx
          .whereType<Map<String, dynamic>>()
          .map(InventoryTransaction.fromJson)
          .toList();
    } else {
      _transactions = _createInitialTransactions();
      await _saveTransactionsToPrefs(prefs);
    }

    // 5. Verbinde Nostr-Callbacks & starte Relay-Verbindung
    nostrService.onStatusChanged = notifyListeners;
    nostrService.onSnapshotReceived = _handleIncomingSnapshot;
    nostrService.onTransactionReceived = _handleIncomingTransaction;
    nostrService.onJoinAnnouncement = _handleIncomingJoinAnnouncement;

    _isInitialized = true;
    notifyListeners();

    // Verbinde im Hintergrund zu den Nostr-Relays
    unawaited(nostrService.connectToRelays(_household));
  }

  List<FreezerItem> itemsInCompartment(String compartmentId) {
    final list = _items.where((i) => i.compartmentId == compartmentId).toList();
    list.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return list;
  }

  List<FreezerItem> searchItems(String query, {FoodCategory? categoryFilter}) {
    final q = query.trim().toLowerCase();
    return _items.where((item) {
      if (categoryFilter != null && item.category != categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return item.name.toLowerCase().contains(q) ||
          (item.brand?.toLowerCase().contains(q) ?? false) ||
          (item.notes?.toLowerCase().contains(q) ?? false) ||
          (item.barcode?.toLowerCase().contains(q) ?? false) ||
          item.addedByName.toLowerCase().contains(q);
    }).toList();
  }

  /// Lagert einen neuen Artikel ein ("Was kommt wo rein") + publiziert über Nostr
  Future<void> addItem({
    required String name,
    String? brand,
    String? barcode,
    required String compartmentId,
    required FoodCategory category,
    required double quantity,
    required String unit,
    required DateTime frozenAt,
    required DateTime expiresAt,
    String? notes,
    Uint8List? photoBytes,
    String? externalImageUrl,
  }) async {
    final itemId = _generateId('item');
    String? uploadedR2Url = externalImageUrl;
    String? thumbBase64;

    if (photoBytes != null) {
      final processed = await R2StorageService.processAndUploadImage(
        rawBytes: photoBytes,
        itemId: itemId,
        r2Config: _household.r2Config,
      );
      thumbBase64 = processed.thumbnailBase64;
      if (processed.uploadedR2Url != null) {
        uploadedR2Url = processed.uploadedR2Url;
      }
    }

    final newItem = FreezerItem(
      id: itemId,
      name: name.trim(),
      brand: brand?.trim(),
      barcode: barcode?.trim(),
      compartmentId: compartmentId,
      category: category,
      quantity: quantity,
      unit: unit,
      frozenAt: frozenAt,
      expiresAt: expiresAt,
      notes: notes?.trim(),
      imageUrl: uploadedR2Url,
      thumbnailBase64: thumbBase64,
      addedByPubkey: _currentUser.pubkey,
      addedByName: _currentUser.displayName,
      updatedAt: DateTime.now(),
    );

    _items.insert(0, newItem);

    final tx = InventoryTransaction(
      id: _generateId('tx'),
      type: TransactionType.checkIn,
      itemId: newItem.id,
      itemName: newItem.name,
      compartmentId: compartmentId,
      quantityDelta: quantity,
      unit: unit,
      actorPubkey: _currentUser.pubkey,
      actorName: _currentUser.displayName,
      timestamp: DateTime.now(),
      note: notes,
    );
    _transactions.insert(0, tx);

    await _persistAll();
    notifyListeners();

    await _syncToNostr(latestTransaction: tx);
  }

  /// Passt die Menge eines Artikels an oder entnimmt ihn komplett ("Was geht wo raus")
  Future<void> adjustItemQuantity(FreezerItem item, double delta, {String? note}) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    final newQuantity = _items[index].quantity + delta;
    late final InventoryTransaction tx;

    if (newQuantity <= 0.001) {
      final removed = _items.removeAt(index);
      tx = InventoryTransaction(
        id: _generateId('tx'),
        type: TransactionType.checkOut,
        itemId: removed.id,
        itemName: removed.name,
        compartmentId: removed.compartmentId,
        quantityDelta: -removed.quantity,
        unit: removed.unit,
        actorPubkey: _currentUser.pubkey,
        actorName: _currentUser.displayName,
        timestamp: DateTime.now(),
        note: note ?? 'Komplett entnommen',
      );
    } else {
      final updated = _items[index].copyWith(
        quantity: newQuantity,
        updatedAt: DateTime.now(),
      );
      _items[index] = updated;
      tx = InventoryTransaction(
        id: _generateId('tx'),
        type: delta < 0 ? TransactionType.checkOut : TransactionType.quantityChange,
        itemId: updated.id,
        itemName: updated.name,
        compartmentId: updated.compartmentId,
        quantityDelta: delta,
        unit: updated.unit,
        actorPubkey: _currentUser.pubkey,
        actorName: _currentUser.displayName,
        timestamp: DateTime.now(),
        note: note,
      );
    }

    _transactions.insert(0, tx);
    await _persistAll();
    notifyListeners();
    await _syncToNostr(latestTransaction: tx);
  }

  /// Räumt einen Artikel von einem Fach in ein anderes um
  Future<void> moveItemToCompartment(FreezerItem item, String targetCompartmentId) async {
    if (item.compartmentId == targetCompartmentId) return;
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    final oldCompartmentId = _items[index].compartmentId;
    final updated = _items[index].copyWith(
      compartmentId: targetCompartmentId,
      updatedAt: DateTime.now(),
    );
    _items[index] = updated;

    final tx = InventoryTransaction(
      id: _generateId('tx'),
      type: TransactionType.moveCompartment,
      itemId: updated.id,
      itemName: updated.name,
      compartmentId: oldCompartmentId,
      targetCompartmentId: targetCompartmentId,
      quantityDelta: updated.quantity,
      unit: updated.unit,
      actorPubkey: _currentUser.pubkey,
      actorName: _currentUser.displayName,
      timestamp: DateTime.now(),
    );
    _transactions.insert(0, tx);

    await _persistAll();
    notifyListeners();
    await _syncToNostr(latestTransaction: tx);
  }

  /// Schaltet für Kühlakkus im Türfach zwischen "Im Schrank" und "In Benutzung (unterwegs)" um
  Future<void> toggleIcePackInUse(FreezerItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    final nextState = !_items[index].isIcePackInUse;
    final updated = _items[index].copyWith(
      isIcePackInUse: nextState,
      updatedAt: DateTime.now(),
    );
    _items[index] = updated;

    final tx = InventoryTransaction(
      id: _generateId('tx'),
      type: TransactionType.icePackToggle,
      itemId: updated.id,
      itemName: updated.name,
      compartmentId: updated.compartmentId,
      quantityDelta: updated.quantity,
      unit: updated.unit,
      actorPubkey: _currentUser.pubkey,
      actorName: _currentUser.displayName,
      timestamp: DateTime.now(),
      note: nextState ? 'Kühlakku entnommen (in Benutzung)' : 'Kühlakku wieder im Türfach',
    );
    _transactions.insert(0, tx);

    await _persistAll();
    notifyListeners();
    await _syncToNostr(latestTransaction: tx);
  }

  // ===========================================================================
  // BENUTZER- & FAMILIENMITGLIEDER-VERWALTUNG (2-ADMIN / HOST-PRINZIP)
  // ===========================================================================

  /// Aktualisiert den eigenen Anzeigenamen & die Profilfarbe
  Future<void> updateCurrentUserProfile({
    required String displayName,
    String? avatarColorHex,
  }) async {
    _currentUser = _currentUser.copyWith(
      displayName: displayName.trim(),
      avatarColorHex: avatarColorHex ?? _currentUser.avatarColorHex,
    );

    final updatedMembers = _household.members.map((m) {
      if (m.pubkey == _currentUser.pubkey) {
        return m.copyWith(
          displayName: _currentUser.displayName,
          colorHex: _currentUser.avatarColorHex,
        );
      }
      return m;
    }).toList();

    _household = _household.copyWith(
      hostName: _household.hostPubkey == _currentUser.pubkey
          ? _currentUser.displayName
          : _household.hostName,
      members: updatedMembers,
    );

    await _persistAll();
    notifyListeners();
    await _syncToNostr();
  }

  /// Einer der 2 Hosts/Admins nimmt ein neues Familienmitglied in die Liste auf!
  /// Wenn kein `existingPubkey` angegeben wird, generiert die App direkt ein neues Schlüsselpaar
  /// und liefert einen personalisierten QR-Code für das neue Familienmitglied zurück.
  Future<PendingMemberInvite> addFamilyMemberByHost({
    required String memberName,
    String? existingPubkey,
    required String colorHex,
    required HouseholdRole role,
  }) async {
    if (!isCurrentUserHost) {
      throw StateError('Nur die (max. 2) Hosts/Admins können neue Familienmitglieder einladen.');
    }

    // Prüfe das 2-Personen-Admin-Limit
    HouseholdRole effectiveRole = role;
    if (role == HouseholdRole.host && !_household.hasOpenAdminSlot) {
      effectiveRole = HouseholdRole.member;
    }

    String pubkey = existingPubkey?.trim() ?? '';
    String generatedPrivkey = '';

    if (pubkey.isEmpty) {
      final pair = NostrCrypto.generateKeyPair();
      pubkey = pair['pubkey']!;
      generatedPrivkey = pair['privkey']!;
    }

    final newMember = HouseholdMember(
      pubkey: pubkey,
      displayName: memberName.trim(),
      role: effectiveRole,
      colorHex: colorHex,
      addedAt: DateTime.now(),
      addedByPubkey: _currentUser.pubkey,
      isActive: true,
    );

    final updatedMembers = List<HouseholdMember>.from(_household.members);
    final existingIndex = updatedMembers.indexWhere((m) => m.pubkey == pubkey);
    if (existingIndex >= 0) {
      updatedMembers[existingIndex] = newMember;
    } else {
      updatedMembers.add(newMember);
    }

    final updatedAdmins = List<String>.from(_household.effectiveAdminPubkeys);
    if (effectiveRole == HouseholdRole.host &&
        !updatedAdmins.contains(pubkey) &&
        updatedAdmins.length < HouseholdConfig.maxAdmins) {
      updatedAdmins.add(pubkey);
    }

    _household = _household.copyWith(
      adminPubkeys: updatedAdmins,
      members: updatedMembers,
    );

    final tx = InventoryTransaction(
      id: _generateId('tx'),
      type: TransactionType.memberAdded,
      itemId: pubkey,
      itemName: memberName.trim(),
      compartmentId: 'drawer_1',
      quantityDelta: 1,
      unit: effectiveRole == HouseholdRole.host ? '2. Admin / Host' : 'Familienmitglied',
      actorPubkey: _currentUser.pubkey,
      actorName: _currentUser.displayName,
      timestamp: DateTime.now(),
      note: effectiveRole == HouseholdRole.host
          ? '${memberName.trim()} als 2. Admin/Host in den Haushalt aufgenommen'
          : '${memberName.trim()} in die Familienmitglieder-Liste aufgenommen',
    );
    _transactions.insert(0, tx);

    await _persistAll();
    notifyListeners();
    await _syncToNostr(latestTransaction: tx);

    final qrPayload = _household.toInviteQrPayload(
      preAssignedMemberName: newMember.displayName,
      preAssignedMemberPrivkey: generatedPrivkey.isNotEmpty ? generatedPrivkey : null,
      preAssignedMemberPubkey: newMember.pubkey,
      assignedRole: effectiveRole,
    );

    return PendingMemberInvite(
      member: newMember,
      generatedPrivkey: generatedPrivkey,
      qrPayload: qrPayload,
    );
  }

  /// Ernennung oder Abberufung des 2. Admins (Der Admin-Posten obliegt max. 2 Personen).
  Future<void> toggleSecondAdminRole(HouseholdMember member) async {
    if (!isCurrentUserHost) return;
    // Der ursprüngliche Haupt-Host bleibt immer Admin
    if (member.pubkey == _household.hostPubkey) return;

    final currentlyAdmin = _household.isHost(member.pubkey);
    if (!currentlyAdmin && !_household.hasOpenAdminSlot) {
      throw StateError(
        'Der Admin-Posten ist bereits mit 2 Personen besetzt. '
        'Entziehe zuerst dem 2. Admin die Rolle, um sie neu zu vergeben.',
      );
    }

    final nextRole = currentlyAdmin ? HouseholdRole.member : HouseholdRole.host;
    final updatedMembers = _household.members.map((m) {
      if (m.pubkey == member.pubkey) {
        return m.copyWith(role: nextRole);
      }
      return m;
    }).toList();

    final updatedAdmins = List<String>.from(_household.effectiveAdminPubkeys);
    if (nextRole == HouseholdRole.host) {
      if (!updatedAdmins.contains(member.pubkey) &&
          updatedAdmins.length < HouseholdConfig.maxAdmins) {
        updatedAdmins.add(member.pubkey);
      }
    } else {
      updatedAdmins.remove(member.pubkey);
    }

    _household = _household.copyWith(
      adminPubkeys: updatedAdmins,
      members: updatedMembers,
    );

    final tx = InventoryTransaction(
      id: _generateId('tx'),
      type: TransactionType.adminChanged,
      itemId: member.pubkey,
      itemName: member.displayName,
      compartmentId: 'drawer_1',
      quantityDelta: 1,
      unit: nextRole.label,
      actorPubkey: _currentUser.pubkey,
      actorName: _currentUser.displayName,
      timestamp: DateTime.now(),
      note: nextRole == HouseholdRole.host
          ? '${member.displayName} wurde zum 2. Host/Admin ernannt'
          : '${member.displayName} ist nun reguläres Familienmitglied',
    );
    _transactions.insert(0, tx);

    await _persistAll();
    notifyListeners();
    await _syncToNostr(latestTransaction: tx);
  }

  /// Entfernt ein Familienmitglied aus der aktiven Liste (nur durch einen der 2 Hosts/Admins)
  Future<void> removeFamilyMemberByHost(String memberPubkey) async {
    if (!isCurrentUserHost) return;
    if (memberPubkey == _household.hostPubkey) return; // Gründer-Host kann nicht gelöscht werden

    HouseholdMember? removedMember;
    final updatedMembers = _household.members.map((m) {
      if (m.pubkey == memberPubkey) {
        removedMember = m;
        return m.copyWith(isActive: false, role: HouseholdRole.member);
      }
      return m;
    }).toList();

    final updatedAdmins = List<String>.from(_household.effectiveAdminPubkeys)
      ..remove(memberPubkey);

    _household = _household.copyWith(
      adminPubkeys: updatedAdmins,
      members: updatedMembers,
    );

    if (removedMember != null) {
      final tx = InventoryTransaction(
        id: _generateId('tx'),
        type: TransactionType.memberRemoved,
        itemId: memberPubkey,
        itemName: removedMember!.displayName,
        compartmentId: 'drawer_1',
        quantityDelta: 0,
        unit: 'Mitglied',
        actorPubkey: _currentUser.pubkey,
        actorName: _currentUser.displayName,
        timestamp: DateTime.now(),
        note: '${removedMember!.displayName} aus der Familienliste entfernt',
      );
      _transactions.insert(0, tx);
      await _persistAll();
      notifyListeners();
      await _syncToNostr(latestTransaction: tx);
    }
  }

  /// Tritt einem Haushalt über einen vom Host generierten Einladungs-QR-Code / Code-String bei
  Future<bool> acceptHouseholdInvite(String rawInviteCode) async {
    final parsed = HouseholdConfig.parseInviteQrPayload(rawInviteCode);
    if (parsed == null) return false;

    // Wenn der Host bereits einen Schlüssel und Namen für dieses Mitglied vorbereitet hat:
    final assignedName = parsed['assignedMemberName']?.toString();
    final assignedPrivkey = parsed['assignedMemberPrivkey']?.toString();
    final assignedPubkey = parsed['assignedMemberPubkey']?.toString();
    final assignedRoleStr = parsed['assignedRole']?.toString();

    if (assignedPrivkey != null &&
        assignedPrivkey.length == 64 &&
        assignedPubkey != null &&
        assignedPubkey.length == 64) {
      _currentUser = _currentUser.copyWith(
        pubkey: assignedPubkey,
        privkey: assignedPrivkey,
        displayName: (assignedName != null && assignedName.isNotEmpty)
            ? assignedName
            : _currentUser.displayName,
      );
    } else if (assignedName != null && assignedName.isNotEmpty) {
      _currentUser = _currentUser.copyWith(displayName: assignedName);
    }

    var importedHousehold = HouseholdConfig.fromJson(parsed);

    // Stelle sicher, dass der eigene Account in der lokalen Mitgliederliste vermerkt ist
    if (!importedHousehold.isMember(_currentUser.pubkey)) {
      final role = (assignedRoleStr == 'host' && importedHousehold.hasOpenAdminSlot)
          ? HouseholdRole.host
          : HouseholdRole.member;
      final selfMember = HouseholdMember(
        pubkey: _currentUser.pubkey,
        displayName: _currentUser.displayName,
        role: role,
        colorHex: _currentUser.avatarColorHex,
        addedAt: DateTime.now(),
        addedByPubkey: importedHousehold.hostPubkey,
      );
      final updatedAdmins = List<String>.from(importedHousehold.effectiveAdminPubkeys);
      if (role == HouseholdRole.host && !updatedAdmins.contains(_currentUser.pubkey)) {
        updatedAdmins.add(_currentUser.pubkey);
      }
      importedHousehold = importedHousehold.copyWith(
        adminPubkeys: updatedAdmins,
        members: [...importedHousehold.members, selfMember],
      );
    }

    _household = importedHousehold;
    await _persistAll();
    notifyListeners();

    await nostrService.connectToRelays(_household);
    await nostrService.publishJoinAnnouncement(
      memberProfile: _currentUser,
      household: _household,
    );
    return true;
  }

  // ===========================================================================
  // CLOUDFLARE R2 KONFIGURATION & BILD-MIGRATION
  // ===========================================================================

  Future<void> updateR2Config(R2Config newConfig) async {
    _household = _household.copyWith(r2Config: newConfig);
    await _persistAll();
    notifyListeners();
    if (isCurrentUserHost) {
      await _syncToNostr();
    }
  }

  /// Lädt alle lokal/als Base64-Thumbnail gespeicherten Bilder nachträglich zu Cloudflare R2 hoch
  Future<int> migratePendingImagesToR2() async {
    if (!_household.r2Config.isConfigured || _isMigratingR2) return 0;

    _isMigratingR2 = true;
    notifyListeners();

    int uploadedCount = 0;
    try {
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (!item.needsR2Upload || item.thumbnailBase64 == null) continue;

        final bytes = base64Decode(item.thumbnailBase64!);
        final url = await R2StorageService.uploadBytesToR2(
          bytes: bytes,
          objectKey: 'eiszeit/items/${item.id}.jpg',
          contentType: 'image/jpeg',
          r2Config: _household.r2Config,
        );

        _items[i] = item.copyWith(
          imageUrl: url,
          updatedAt: DateTime.now(),
        );
        uploadedCount++;
      }

      if (uploadedCount > 0) {
        await _persistAll();
        await _syncToNostr();
      }
    } finally {
      _isMigratingR2 = false;
      notifyListeners();
    }
    return uploadedCount;
  }

  Future<void> updateRelays(List<String> newRelays) async {
    final cleaned = newRelays
        .map((r) => r.trim())
        .where((r) => r.startsWith('wss://') || r.startsWith('ws://'))
        .toSet()
        .toList();
    if (cleaned.isEmpty) return;

    _household = _household.copyWith(relays: cleaned);
    await _persistAll();
    notifyListeners();

    await nostrService.connectToRelays(_household);
    if (isCurrentUserHost) {
      await _syncToNostr();
    }
  }

  Future<void> manualSyncNow() async {
    await nostrService.connectToRelays(_household);
    await _syncToNostr();
    _lastSyncMessage = 'Nostr-Synchronisation ausgeführt (${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} Uhr)';
    notifyListeners();
  }

  // ===========================================================================
  // EINGEHENDE NOSTR-EVENTS VERARBEITEN
  // ===========================================================================

  void _handleIncomingSnapshot({
    required List<FreezerItem> items,
    required HouseholdConfig updatedHousehold,
    required String senderPubkey,
    required DateTime timestamp,
  }) {
    if (senderPubkey == _currentUser.pubkey) return;

    // Merge Artikel nach aktuellerem `updatedAt`
    final mergedMap = <String, FreezerItem>{};
    for (final incoming in items) {
      mergedMap[incoming.id] = incoming;
    }
    _items = mergedMap.values.toList();

    // Wenn der Sender einer der 2 Hosts/Admins ist, übernehme aktualisierte Mitgliederliste & R2-Config
    if (_household.isHost(senderPubkey)) {
      _household = updatedHousehold;
    }

    _lastSyncMessage = 'Bestand über Nostr aktualisiert';
    unawaited(_persistAll());
    notifyListeners();
  }

  void _handleIncomingTransaction(InventoryTransaction transaction) {
    if (_transactions.any((t) => t.id == transaction.id)) return;
    _transactions.insert(0, transaction);
    if (_transactions.length > 250) {
      _transactions = _transactions.sublist(0, 250);
    }
    unawaited(_persistAll());
    notifyListeners();
  }

  void _handleIncomingJoinAnnouncement({
    required String memberPubkey,
    required String memberName,
    required String colorHex,
  }) {
    // Wenn dieser Benutzer einer der 2 Hosts/Admins ist, nimmt er das eingeladene Mitglied automatisch in die Liste auf
    if (!isCurrentUserHost) return;
    if (_household.isMember(memberPubkey)) return;

    final newMember = HouseholdMember(
      pubkey: memberPubkey,
      displayName: memberName,
      role: HouseholdRole.member,
      colorHex: colorHex,
      addedAt: DateTime.now(),
      addedByPubkey: _currentUser.pubkey,
    );
    _household = _household.copyWith(
      members: [..._household.members, newMember],
    );
    unawaited(_persistAll());
    unawaited(_syncToNostr());
    notifyListeners();
  }

  Future<void> _syncToNostr({InventoryTransaction? latestTransaction}) async {
    if (!isCurrentUserAuthorized) return;
    if (latestTransaction != null) {
      await nostrService.publishTransaction(
        author: _currentUser,
        household: _household,
        transaction: latestTransaction,
      );
    }
    await nostrService.publishSnapshot(
      author: _currentUser,
      household: _household,
      items: _items,
    );
  }

  Future<void> _persistAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefProfileKey, jsonEncode(_currentUser.toJson()));
    await prefs.setString(_prefHouseholdKey, jsonEncode(_household.toJson()));
    await _saveItemsToPrefs(prefs);
    await _saveTransactionsToPrefs(prefs);
  }

  Future<void> _saveItemsToPrefs(SharedPreferences prefs) async {
    final encoded = jsonEncode(_items.map((i) => i.toJson()).toList());
    await prefs.setString(_prefItemsKey, encoded);
  }

  Future<void> _saveTransactionsToPrefs(SharedPreferences prefs) async {
    final encoded = jsonEncode(_transactions.map((t) => t.toJson()).toList());
    await prefs.setString(_prefTransactionsKey, encoded);
  }

  String _generateId(String prefix) {
    final rand = Random.secure().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }

  /// Startbestand passend zu den sichtbaren Artikeln auf dem Foto des neuen Siemens NoFrost Gefrierschranks
  List<FreezerItem> _createInitialPhotoInventory() {
    final now = DateTime.now();
    return [
      FreezerItem(
        id: 'init_blueberries',
        name: 'Kultur-Heidelbeeren',
        brand: 'Erntefrisch TK',
        compartmentId: 'drawer_2',
        category: FoodCategory.berriesAndFruit,
        quantity: 1,
        unit: 'Beutel (750g)',
        frozenAt: now.subtract(const Duration(days: 2)),
        expiresAt: DateTime(now.year, now.month + 10, now.day),
        notes: 'In Schublade 2 rechts eingelagert',
        addedByPubkey: _currentUser.pubkey,
        addedByName: _currentUser.displayName,
        updatedAt: now,
      ),
      FreezerItem(
        id: 'init_veggie_box',
        name: 'TK-Kräuter / Gemüse-Box',
        brand: 'Bio',
        compartmentId: 'drawer_3',
        category: FoodCategory.vegetablesAndHerbs,
        quantity: 1,
        unit: 'Packung',
        frozenAt: now.subtract(const Duration(days: 3)),
        expiresAt: DateTime(now.year, now.month + 10, now.day),
        notes: 'Schublade 3 oben links',
        addedByPubkey: _currentUser.pubkey,
        addedByName: _currentUser.displayName,
        updatedAt: now,
      ),
      FreezerItem(
        id: 'init_soup_bags',
        name: 'Gefrierbeutel (Brühe / Vorrat)',
        compartmentId: 'drawer_3',
        category: FoodCategory.cookedAndMeals,
        quantity: 3,
        unit: 'Beutel',
        frozenAt: now.subtract(const Duration(days: 4)),
        expiresAt: DateTime(now.year, now.month + 4, now.day),
        notes: 'Schublade 3 liegend gestapelt',
        addedByPubkey: _currentUser.pubkey,
        addedByName: _currentUser.displayName,
        updatedAt: now,
      ),
      FreezerItem(
        id: 'init_icepacks_white',
        name: 'Große Kühlakkus (Weiß)',
        brand: 'Siemens Türfach',
        compartmentId: 'door_icepacks',
        category: FoodCategory.icePacks,
        quantity: 2,
        unit: 'Stück',
        frozenAt: now.subtract(const Duration(days: 5)),
        expiresAt: DateTime(now.year + 5, now.month, now.day),
        notes: 'Im Tür-Kühlakku-Halter einsatzbereit',
        addedByPubkey: _currentUser.pubkey,
        addedByName: _currentUser.displayName,
        updatedAt: now,
      ),
      FreezerItem(
        id: 'init_icepack_blue',
        name: 'Gel-Kühlakku (Blau)',
        compartmentId: 'door_icepacks',
        category: FoodCategory.icePacks,
        quantity: 1,
        unit: 'Stück',
        frozenAt: now.subtract(const Duration(days: 5)),
        expiresAt: DateTime(now.year + 5, now.month, now.day),
        notes: 'Im Türfach vorne',
        addedByPubkey: _currentUser.pubkey,
        addedByName: _currentUser.displayName,
        updatedAt: now,
      ),
    ];
  }

  List<InventoryTransaction> _createInitialTransactions() {
    final now = DateTime.now();
    return [
      InventoryTransaction(
        id: 'init_tx_1',
        type: TransactionType.checkIn,
        itemId: 'init_blueberries',
        itemName: 'Kultur-Heidelbeeren',
        compartmentId: 'drawer_2',
        quantityDelta: 1,
        unit: 'Beutel (750g)',
        actorPubkey: _currentUser.pubkey,
        actorName: _currentUser.displayName,
        timestamp: now.subtract(const Duration(hours: 2)),
        note: 'Ersteinrichtung des neuen Siemens NoFrost Gefrierschranks',
      ),
      InventoryTransaction(
        id: 'init_tx_2',
        type: TransactionType.checkIn,
        itemId: 'init_soup_bags',
        itemName: 'Gefrierbeutel (Brühe / Vorrat)',
        compartmentId: 'drawer_3',
        quantityDelta: 3,
        unit: 'Beutel',
        actorPubkey: _currentUser.pubkey,
        actorName: _currentUser.displayName,
        timestamp: now.subtract(const Duration(hours: 3)),
      ),
    ];
  }
}
