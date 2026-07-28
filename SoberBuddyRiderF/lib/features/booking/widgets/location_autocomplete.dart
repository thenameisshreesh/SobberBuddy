import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/places_service.dart';

typedef LocationSelectCallback = void Function(Map<String, dynamic> location);

class LocationAutocomplete extends ConsumerStatefulWidget {
  const LocationAutocomplete({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onLocationSelect,
    required this.placeholder,
    required this.icon,
    required this.iconColor,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final LocationSelectCallback onLocationSelect;
  final String placeholder;
  final IconData icon;
  final Color iconColor;

  @override
  ConsumerState<LocationAutocomplete> createState() =>
      _LocationAutocompleteState();
}

class _LocationAutocompleteState extends ConsumerState<LocationAutocomplete> {
  late final TextEditingController _controller;
  List<PlaceSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  bool _loading = false;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _loading = true);
    try {
      final places = ref.read(placesServiceProvider);
      final results = await places.autocomplete(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSuggestionPress(PlaceSuggestion suggestion) async {
    setState(() {
      _isSelecting = true;
      _loading = true;
      _showSuggestions = false;
      _suggestions = [];
    });

    widget.onChanged(suggestion.title);
    _controller.text = suggestion.title;

    try {
      final places = ref.read(placesServiceProvider);
      final completeLocation = await places.resolvePlaceSelection(suggestion);
      final resolvedTitle = completeLocation['title'] as String? ?? suggestion.title;
      widget.onChanged(resolvedTitle);
      _controller.text = resolvedTitle;
      widget.onLocationSelect(completeLocation);
    } catch (_) {
      widget.onLocationSelect({
        ...suggestion.toMap(),
        'coordinates': const {
          'latitude': 28.6139,
          'longitude': 77.2090,
        },
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _isSelecting = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(LocationAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }

    if (_isSelecting) {
      _isSelecting = false;
      return;
    }

    if (widget.value.length > 2 && widget.value != oldWidget.value) {
      _fetchSuggestions(widget.value);
    } else if (widget.value.length <= 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 20, color: widget.iconColor),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: (value) {
                  widget.onChanged(value);
                  if (_isSelecting) return;
                  if (value.length > 2) {
                    _fetchSuggestions(value);
                  } else {
                    setState(() {
                      _suggestions = [];
                      _showSuggestions = false;
                    });
                  }
                },
                onTap: () {
                  if (widget.value.length > 2 && _suggestions.isNotEmpty) {
                    setState(() => _showSuggestions = true);
                  }
                },
                style: const TextStyle(fontSize: 16, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            if (_loading)
              const Icon(
                Icons.access_time,
                size: 16,
                color: AppColors.textSecondary,
              ),
          ],
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: AppColors.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: AppColors.border,
                ),
                itemBuilder: (context, index) {
                  final item = _suggestions[index];
                  return InkWell(
                    onTap: () => _handleSuggestionPress(item),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.text,
                                  ),
                                ),
                                if (item.description.isNotEmpty)
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
