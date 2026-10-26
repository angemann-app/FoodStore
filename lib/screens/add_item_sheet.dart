import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/freezer_compartment.dart';
import '../services/app_state.dart';
import '../services/openfoodfacts_service.dart';

class AddItemSheet extends StatefulWidget {
  final AppState appState;
  final String initialCompartmentId;

  const AddItemSheet({
    super.key,
    required this.appState,
    this.initialCompartmentId = 'drawer_2',
  });

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();

  late String _selectedCompartmentId;
  FoodCategory _selectedCategory = FoodCategory.berriesAndFruit;
  String _selectedUnit = 'Beutel';
  DateTime _frozenAt = DateTime.now();
  late DateTime _expiresAt;

  Uint8List? _photoBytes;
  String? _externalImageUrl;
  bool _isLookingUpBarcode = false;
  bool _isSaving = false;

  static const List<String> _units = [
    'Beutel',
    'Packung',
    'Stück',
    'Portion',
    'Dose',
    'g',
    'kg',
  ];

  static const List<Map<String, dynamic>> _quickTemplates = [
    {'name': 'Kultur-Heidelbeeren', 'cat': FoodCategory.berriesAndFruit, 'unit': 'Beutel', 'comp': 'drawer_2'},
    {'name': 'Brötchen zum Aufbacken', 'cat': FoodCategory.breadAndBakery, 'unit': 'Stück', 'comp': 'drawer_5'},
    {'name': 'Rinderhackfleisch', 'cat': FoodCategory.meatAndPoultry, 'unit': 'Packung', 'comp': 'drawer_5'},
    {'name': 'Bolognese (selbstgekocht)', 'cat': FoodCategory.cookedAndMeals, 'unit': 'Dose', 'comp': 'drawer_3'},
    {'name': 'Steinofen-Pizza', 'cat': FoodCategory.pizzaAndSnacks, 'unit': 'Packung', 'comp': 'big_box'},
    {'name': 'Lachsfilet', 'cat': FoodCategory.fishAndSeafood, 'unit': 'Packung', 'comp': 'drawer_5'},
    {'name': 'Gartenkräuter gehackt', 'cat': FoodCategory.vegetablesAndHerbs, 'unit': 'Dose', 'comp': 'drawer_1'},
    {'name': 'Kühlakku', 'cat': FoodCategory.icePacks, 'unit': 'Stück', 'comp': 'door_icepacks'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCompartmentId = widget.initialCompartmentId;
    if (_selectedCompartmentId == 'door_icepacks') {
      _selectedCategory = FoodCategory.icePacks;
      _selectedUnit = 'Stück';
    } else if (_selectedCompartmentId == 'big_box') {
      _selectedCategory = FoodCategory.pizzaAndSnacks;
      _selectedUnit = 'Packung';
    }
    _recalculateExpiry();
  }

  void _recalculateExpiry() {
    _expiresAt = DateTime(
      _frozenAt.year,
      _frozenAt.month + _selectedCategory.recommendedMonths,
      _frozenAt.day,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _barcodeCtrl.dispose();
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _BarcodeScannerModal(),
    );
    if (code == null || code.isEmpty) return;

    setState(() {
      _barcodeCtrl.text = code;
      _isLookingUpBarcode = true;
    });

    final product = await OpenFoodFactsService.lookupBarcode(code);
    if (!mounted) return;

    setState(() {
      _isLookingUpBarcode = false;
      if (product != null) {
        _nameCtrl.text = product.name;
        if (product.brand != null) _brandCtrl.text = product.brand!;
        _selectedCategory = product.suggestedCategory;
        _externalImageUrl = product.imageUrl;
        _recalculateExpiry();
      }
    });

    if (product == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode $code gescannt – bitte Name kurz ergänzen.'),
        ),
      );
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kamera/Galerie nicht verfügbar: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final qty = double.tryParse(_quantityCtrl.text.replaceAll(',', '.')) ?? 1.0;

    await widget.appState.addItem(
      name: _nameCtrl.text,
      brand: _brandCtrl.text,
      barcode: _barcodeCtrl.text,
      compartmentId: _selectedCompartmentId,
      category: _selectedCategory,
      quantity: qty,
      unit: _selectedUnit,
      frozenAt: _frozenAt,
      expiresAt: _expiresAt,
      notes: _notesCtrl.text,
      photoBytes: _photoBytes,
      externalImageUrl: _externalImageUrl,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final r2Configured = widget.appState.household.r2Config.isConfigured;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF005691).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.move_to_inbox_rounded,
                          color: Color(0xFF005691),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gefriergut einlagern ("Was kommt wo rein")',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Eingelagert von ${widget.appState.currentUser.displayName} • Sync über Nostr',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Schnell-Buttons: Barcode scannen & Foto aufnehmen
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLookingUpBarcode ? null : _scanBarcode,
                          icon: _isLookingUpBarcode
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.qr_code_scanner),
                          label: const Text('Barcode scannen'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickPhoto(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(r2Configured ? 'Foto (R2 Cloud)' : 'Foto machen'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        tooltip: 'Aus Galerie wählen',
                        onPressed: () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                      ),
                    ],
                  ),

                  if (_photoBytes != null || _externalImageUrl != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _photoBytes != null
                                ? Image.memory(
                                    _photoBytes!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    _externalImageUrl!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              r2Configured
                                  ? 'Foto bereit – wird beim Speichern automatisch in deinen Cloudflare R2 Bucket geladen.'
                                  : 'Foto bereit – wird als Nostr-Vorschau gespeichert (später 1-Klick-Upload zu Cloudflare R2 möglich).',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              _photoBytes = null;
                              _externalImageUrl = null;
                            }),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Text(
                    'Schnellauswahl-Vorlagen:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickTemplates.map((tpl) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(
                              tpl['name'] as String,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                _nameCtrl.text = tpl['name'] as String;
                                _selectedCategory = tpl['cat'] as FoodCategory;
                                _selectedUnit = tpl['unit'] as String;
                                _selectedCompartmentId = tpl['comp'] as String;
                                _recalculateExpiry();
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Was wird eingelagert? *',
                      hintText: 'z. B. Kultur-Heidelbeeren, Rinderfilet, Bolognese',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fastfood_outlined),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Bitte Bezeichnung eingeben' : null,
                  ),
                  const SizedBox(height: 12),

                  // Wo kommt es rein? (Siemens 6 Fächer + Türfach)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCompartmentId,
                    decoration: const InputDecoration(
                      labelText: 'Wo kommt es rein? (Siemens Fach-Auswahl)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.kitchen),
                    ),
                    items: FreezerCompartment.siemensNoFrostCompartments.map((comp) {
                      return DropdownMenuItem<String>(
                        value: comp.id,
                        child: Text(
                          '${comp.title} – ${comp.subtitle}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCompartmentId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Kategorie
                  DropdownButtonFormField<FoodCategory>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategorie (bestimmt Haltbarkeits-Empfehlung)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: FoodCategory.values.map((cat) {
                      return DropdownMenuItem<FoodCategory>(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(cat.icon, color: cat.color, size: 18),
                            const SizedBox(width: 8),
                            Text('${cat.label} (~${cat.recommendedMonths} Mon.)'),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                          _recalculateExpiry();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Menge & Einheit
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _quantityCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Menge *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Einheit',
                            border: OutlineInputBorder(),
                          ),
                          items: _units
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedUnit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Einfrierdatum & Empfohlenes Verbrauchsdatum gegen Gefrierbrand
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _frozenAt,
                              firstDate: DateTime(2023),
                              lastDate: DateTime.now().add(const Duration(days: 7)),
                            );
                            if (picked != null) {
                              setState(() {
                                _frozenAt = picked;
                                _recalculateExpiry();
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Einfrierdatum',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.ac_unit),
                            ),
                            child: Text(dateFormatter.format(_frozenAt)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expiresAt,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 6)),
                            );
                            if (picked != null) {
                              setState(() => _expiresAt = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Haltbar bis (Gefrierbrand)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.event_available),
                            ),
                            child: Text(dateFormatter.format(_expiresAt)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _brandCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Marke / Herkunft (optional)',
                            hintText: 'z. B. Eigener Garten, Bio, Edeka',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Notiz / Position im Fach',
                            hintText: 'z. B. Links hinten, für Sonntag',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF005691),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      'In ${FreezerCompartment.byId(_selectedCompartmentId).title} einlagern',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BarcodeScannerModal extends StatefulWidget {
  const _BarcodeScannerModal();

  @override
  State<_BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<_BarcodeScannerModal> {
  bool _hasPopped = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Column(
        children: [
          AppBar(
            title: const Text('EAN-Barcode scannen'),
             automaticallyImplyLeading: false,
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (_hasPopped) return;
                for (final barcode in capture.barcodes) {
                  final val = barcode.rawValue;
                  if (val != null && val.isNotEmpty) {
                    _hasPopped = true;
                    Navigator.of(context).pop(val);
                    break;
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
