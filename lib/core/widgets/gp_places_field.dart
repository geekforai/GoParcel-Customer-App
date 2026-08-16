import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../services/places_service.dart';

typedef PlaceSelected = void Function(PlaceDetails place);

/// Compact searchable address field with Places suggestions dropdown.
class GpPlacesField extends StatefulWidget {
  const GpPlacesField({
    super.key,
    required this.controller,
    required this.onPlaceSelected,
    this.label = 'Address',
    this.hintText = 'Search area, landmark, address',
    this.prefixIcon,
    this.accentColor,
    this.enabled = true,
    this.onFocusChanged,
  });

  final TextEditingController controller;
  final PlaceSelected onPlaceSelected;
  final String label;
  final String hintText;
  final IconData? prefixIcon;
  final Color? accentColor;
  final bool enabled;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<GpPlacesField> createState() => _GpPlacesFieldState();
}

class _GpPlacesFieldState extends State<GpPlacesField> {
  final _focus = FocusNode();
  final _places = PlacesService();
  final _session = DateTime.now().millisecondsSinceEpoch.toString();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _loading = false;
  bool _suppressNext = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      widget.onFocusChanged?.call(_focus.hasFocus);
      if (!_focus.hasFocus) {
        // Keep list briefly so tap can register; clear after
        Future<void>.delayed(const Duration(milliseconds: 180), () {
          if (mounted && !_focus.hasFocus) {
            setState(() => _suggestions = const []);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_suppressNext) {
      _suppressNext = false;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      final q = value.trim();
      if (q.length < 2) {
        setState(() {
          _suggestions = const [];
          _loading = false;
        });
        return;
      }
      setState(() => _loading = true);
      final list = await _places.autocomplete(q, sessionToken: _session);
      if (!mounted) return;
      setState(() {
        _suggestions = list;
        _loading = false;
      });
    });
  }

  Future<void> _select(PlaceSuggestion s) async {
    setState(() {
      _loading = true;
      _suggestions = const [];
    });
    final details = await _places.details(s.placeId, sessionToken: _session);
    if (!mounted) return;
    setState(() => _loading = false);
    if (details == null) return;
    _suppressNext = true;
    widget.controller.text = details.address.isNotEmpty
        ? details.address
        : s.description;
    _focus.unfocus();
    widget.onPlaceSelected(details);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTypography.textTheme.labelLarge?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          enabled: widget.enabled,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: AppTypography.textTheme.bodyMedium,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            prefixIcon: Icon(
              widget.prefixIcon ?? Icons.search_rounded,
              color: accent,
              size: 20,
            ),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (widget.controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          widget.controller.clear();
                          setState(() => _suggestions = const []);
                        },
                      )
                    : null),
            filled: true,
            fillColor: AppColors.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent, width: 1.4),
            ),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length.clamp(0, 5),
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, i) {
                final s = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.place_outlined, color: accent, size: 20),
                  title: Text(
                    s.mainText.isNotEmpty ? s.mainText : s.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.textTheme.bodyMedium,
                  ),
                  subtitle: s.secondaryText.isEmpty
                      ? null
                      : Text(
                          s.secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.textTheme.bodySmall,
                        ),
                  onTap: () => _select(s),
                );
              },
            ),
          ),
      ],
    );
  }
}
