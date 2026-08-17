import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/content/goparcel_content.dart';
import '../../../../core/locale/app_locale.dart';
import '../../../../core/utils/fare_calculator.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/order.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_ui.dart';

class ParcelDetailsScreen extends ConsumerStatefulWidget {
  const ParcelDetailsScreen({super.key});

  @override
  ConsumerState<ParcelDetailsScreen> createState() =>
      _ParcelDetailsScreenState();
}

class _ParcelDetailsScreenState extends ConsumerState<ParcelDetailsScreen> {
  ParcelType _type = ParcelType.documents;
  WeightBand _weight = WeightBand.oneTo5;
  FareVehicle _vehicle = FareVehicle.twoWheeler;
  bool _electric = true;
  bool _acceptedRules = false;
  double _tip = 0;
  final _instructions = TextEditingController();
  String? _photoPath;
  bool _loading = false;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,
    );
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _bookNow() async {
    if (!_acceptedRules) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Please accept Read Before Booking to continue'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    final notifier = ref.read(bookingProvider.notifier);
    final saved = await notifier.saveParcel(
      type: _type,
      weight: _weight,
      instructions: _instructions.text.trim(),
      photoPath: _photoPath,
      electric: _electric,
      tip: _tip,
      fareVehicle: _vehicle,
    );
    if (!saved) {
      if (mounted) {
        setState(() => _loading = false);
        final msg =
            ref.read(bookingProvider).errorMessage ?? 'Unable to save parcel';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
        );
      }
      return;
    }
    final started = await notifier.startSearch();
    if (!mounted) return;
    setState(() => _loading = false);
    if (started) {
      context.go(RoutePaths.bookingSearching);
    } else {
      final msg =
          ref.read(bookingProvider).errorMessage ?? 'Unable to start search';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
      );
    }
  }

  InputDecorationTheme get _menuDecoration {
    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(l10nProvider);
    final order = ref.watch(bookingProvider).order;
    final km = order == null
        ? 0.0
        : FareCalculator.haversineKm(order.pickup.point, order.drop.point);
    final availableVehicles = FareVehicle.values
        .where((v) => FareCalculator.isVehicleAvailable(v, km))
        .toList();
    if (!availableVehicles.contains(_vehicle) && availableVehicles.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _vehicle = availableVehicles.first);
      });
    }
    final fare = order == null
        ? null
        : FareCalculator.estimateForKm(
            km: km,
            vehicle: _vehicle,
            tip: _tip,
          );

    final types = <(ParcelType, IconData, String)>[
      (ParcelType.documents, Icons.description_outlined, s.documents),
      (ParcelType.electronics, Icons.devices_other_outlined, s.electronics),
      (ParcelType.clothes, Icons.checkroom_outlined, s.clothes),
      (ParcelType.food, Icons.fastfood_outlined, s.food),
      (ParcelType.others, Icons.inventory_2_outlined, s.others),
    ];
    final weights = <(WeightBand, String)>[
      (WeightBand.upTo1, '≤ 1 KG'),
      (WeightBand.oneTo5, '1–5 KG'),
      (WeightBand.fiveTo10, '5–10 KG'),
      (WeightBand.tenPlus, '10+ KG'),
    ];

    String vehicleLabel(FareVehicle v) => switch (v) {
          FareVehicle.twoWheeler => '2-Wheeler / Bike',
          FareVehicle.mini3Wheeler => 'Mini 3-Wheeler',
          FareVehicle.threeWheeler => '3-Wheeler',
          FareVehicle.tataAce => 'Tata Ace',
          FareVehicle.pickup8ft => 'Pickup 8ft',
        };

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: BookingRoundButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => context.pop(),
          ),
        ),
        title: Text(
          s.parcelDetails,
          style: AppTypography.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (order != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookingRouteStrip(
                    pickup: order.pickup.address,
                    drop: order.drop.address,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Distance ≈ ${km.toStringAsFixed(1)} km',
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select vehicle',
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in availableVehicles)
                      ChoiceChip(
                        label: Text(vehicleLabel(v)),
                        selected: _vehicle == v,
                        onSelected: (_) => setState(() => _vehicle = v),
                      ),
                  ],
                ),
                if (km > 40) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Mini 3-Wheeler is not available above 40 km.',
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  s.vehicle,
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: [
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(s.electric),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.local_gas_station_outlined, size: 18),
                      label: Text(s.fuel),
                    ),
                  ],
                  selected: {_electric},
                  onSelectionChanged: (v) =>
                      setState(() => _electric = v.first),
                ),
                if (_electric) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.evBenefit,
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownMenu<ParcelType>(
                  key: ValueKey(_type),
                  initialSelection: _type,
                  expandedInsets: EdgeInsets.zero,
                  leadingIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                  label: Text(s.sending),
                  inputDecorationTheme: _menuDecoration,
                  dropdownMenuEntries: [
                    for (final t in types)
                      DropdownMenuEntry(
                        value: t.$1,
                        label: t.$3,
                        leadingIcon: Icon(t.$2, size: 20),
                      ),
                  ],
                  onSelected: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownMenu<WeightBand>(
                  key: ValueKey(_weight),
                  initialSelection: _weight,
                  expandedInsets: EdgeInsets.zero,
                  leadingIcon: const Icon(Icons.scale_outlined, size: 20),
                  label: Text(s.weight),
                  inputDecorationTheme: _menuDecoration,
                  dropdownMenuEntries: [
                    for (final w in weights)
                      DropdownMenuEntry(value: w.$1, label: w.$2),
                  ],
                  onSelected: (v) {
                    if (v != null) setState(() => _weight = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _instructions,
                  maxLines: 2,
                  decoration: _fieldDecoration(
                    label: s.instructions,
                    icon: Icons.notes_rounded,
                  ).copyWith(hintText: s.instructionsHint, prefixIcon: null),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _photoPath != null
                            ? AppColors.success
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _photoPath != null
                              ? Icons.check_circle_rounded
                              : Icons.camera_alt_outlined,
                          color: _photoPath != null
                              ? AppColors.success
                              : AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _photoPath == null ? s.addPhoto : s.photoAdded,
                            style: AppTypography.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _photoPath != null
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Read Before Booking',
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final rule in GoParcelContent.readBeforeBooking)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(fontWeight: FontWeight.w700)),
                        Expanded(
                          child: Text(
                            rule,
                            style: AppTypography.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acceptedRules,
                  onChanged: (v) =>
                      setState(() => _acceptedRules = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'I have read and agree to these booking rules',
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 8,
        shadowColor: const Color(0x14000000),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (fare != null)
                  Row(
                    children: [
                      Text(
                        s.estimatedFare,
                        style: AppTypography.textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Text(
                        Formatters.currency(fare),
                        style: AppTypography.textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      s.tipOptional,
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in [0, 10, 20, 50])
                            ChoiceChip(
                              label: Text(t == 0 ? s.noTip : '₹$t'),
                              selected: _tip == t,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: (_) =>
                                  setState(() => _tip = t.toDouble()),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                BookingPrimaryButton(
                  label: s.bookNow,
                  isLoading: _loading,
                  onPressed: _bookNow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
