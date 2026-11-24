import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/desi_buttons.dart';
import '../../../core/widgets/game_card_widget.dart';
import '../../../models/game_models.dart';
import '../../../shared/app_providers.dart';

/// Custom Card Creator screen with live collectible card preview.
class CustomCardCreatorScreen extends ConsumerStatefulWidget {
  const CustomCardCreatorScreen({super.key, required this.boardId});
  final String boardId;

  @override
  ConsumerState<CustomCardCreatorScreen> createState() =>
      _CustomCardCreatorScreenState();
}

class _CustomCardCreatorScreenState
    extends ConsumerState<CustomCardCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _attrKeyCtrl = TextEditingController(text: 'Trait');
  final _attrValCtrl = TextEditingController();
  final Uuid _uuid = const Uuid();

  GameCategory _category = GameCategory.custom;
  CardDifficulty _difficulty = CardDifficulty.medium;
  String _iconName = 'sparkles';
  int _accentHex = 0xFF8B5CF6;

  static const _icons = [
    'sparkles',
    'cricket',
    'movie',
    'music',
    'food',
    'travel',
    'tech',
    'meme',
  ];

  static const _colors = [
    0xFF8B5CF6,
    0xFFFF9933,
    0xFF2DD4BF,
    0xFFEC4899,
    0xFF22C55E,
    0xFFEF4444,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _imageUrlCtrl.dispose();
    _attrKeyCtrl.dispose();
    _attrValCtrl.dispose();
    super.dispose();
  }

  GameCard _buildPreviewCard() {
    final attrs = <String, String>{};
    if (_attrKeyCtrl.text.trim().isNotEmpty &&
        _attrValCtrl.text.trim().isNotEmpty) {
      attrs[_attrKeyCtrl.text.trim()] = _attrValCtrl.text.trim();
    }
    return GameCard(
      id: 'cc_${_uuid.v4().substring(0, 8)}',
      name: _nameCtrl.text.trim().isEmpty
          ? 'Card Preview'
          : _nameCtrl.text.trim(),
      category: _category,
      imageUrl: _imageUrlCtrl.text.trim(),
      iconName: _iconName,
      accentHex: _accentHex,
      description: _descCtrl.text.trim().isEmpty
          ? 'Custom player-created card'
          : _descCtrl.text.trim(),
      difficulty: _difficulty,
      keywords: [_nameCtrl.text.trim().toLowerCase()],
      attributes: attrs,
    );
  }

  Future<void> _saveCard({required bool addAnother}) async {
    if (!_formKey.currentState!.validate()) return;
    final card = _buildPreviewCard();
    await ref
        .read(customBoardsProvider.notifier)
        .addCardToBoard(boardId: widget.boardId, card: card);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${card.name}" to your board!')),
    );
    if (addAnother) {
      _nameCtrl.clear();
      _descCtrl.clear();
      _imageUrlCtrl.clear();
      _attrValCtrl.clear();
      setState(() {});
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildPreviewCard();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Custom Card')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SizedBox(
                    width: 146,
                    height: 190,
                    child: GameCardWidget(card: preview, onTap: () {}),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Card Name *',
                    hintText: 'e.g., Hostel Warden, Chai Tapri',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a card name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Short clue or fun bio',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Optional Image URL (or use emblem below)',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _attrKeyCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Attribute Label',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _attrValCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Attribute Value',
                          hintText: 'e.g., Funny',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<GameCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Card Tag'),
                  items: GameCategory.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CardDifficulty>(
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: CardDifficulty.values
                      .map(
                        (d) => DropdownMenuItem(value: d, child: Text(d.label)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _difficulty = v);
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Card Accent & Icon',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: _colors.map((hex) {
                    return GestureDetector(
                      onTap: () => setState(() => _accentHex = hex),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(hex),
                          shape: BoxShape.circle,
                          border: _accentHex == hex
                              ? Border.all(color: Colors.white, width: 2.5)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _icons.map((ic) {
                    return ChoiceChip(
                      label: Text(ic),
                      selected: _iconName == ic,
                      onSelected: (_) => setState(() => _iconName = ic),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: DesiSecondaryButton(
                        label: 'Save & Add Another',
                        onPressed: () => _saveCard(addAnother: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DesiPrimaryButton(
                        label: 'Save Card',
                        onPressed: () => _saveCard(addAnother: false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
