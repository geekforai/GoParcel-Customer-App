import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/route_paths.dart';
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
  final _instructions = TextEditingController();
  String? _photoPath;
  bool _loading = false;

  static const _types = [
    (ParcelType.documents, Icons.description_outlined, 'Documents'),
    (ParcelType.electronics, Icons.devices_other_outlined, 'Electronics'),
    (ParcelType.food, Icons.restaurant_outlined, 'Food'),
    (ParcelType.clothes, Icons.checkroom_outlined, 'Clothes'),
    (ParcelType.others, Icons.inventory_2_outlined, 'Others'),
  ];

  static const _weights = [
    (WeightBand.upTo1, '≤ 1 KG'),
    (WeightBand.oneTo5, '1–5 KG'),
    (WeightBand.fiveTo10, '5–10 KG'),
    (WeightBand.tenPlus, '10+ KG'),
  ];

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      setState(() => _photoPath = file.path);
    }
  }

  Future<void> _bookNow() async {
    setState(() => _loading = true);
    final notifier = ref.read(bookingProvider.notifier);
    final saved = await notifier.saveParcel(
      type: _type,
      weight: _weight,
      instructions: _instructions.text.trim(),
      photoPath: _photoPath,
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

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(bookingProvider).order;
    final fare = order?.fare;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  BookingRoundButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Parcel details',
                      style: AppTypography.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (order != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFEFF6FF)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: BookingRouteStrip(
                    pickup: order.pickup.address,
                    drop: order.drop.address,
                  ),
                ),
              ),
            ],
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                children: [
                  Text(
                    'What are you sending?',
                    style: AppTypography.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.0,
                    children: _types.map((t) {
                      final selected = _type == t.$1;
                      return InkWell(
                        onTap: () => setState(() => _type = t.$1),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryLight
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: selected ? 1.6 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                t.$2,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t.$3,
                                style: AppTypography.textTheme.labelMedium
                                    ?.copyWith(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Weight',
                    style: AppTypography.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: _weights.map((w) {
                      final selected = _weight == w.$1;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: w != _weights.last ? 8 : 0,
                          ),
                          child: InkWell(
                            onTap: () => setState(() => _weight = w.$1),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                w.$2,
                                textAlign: TextAlign.center,
                                style: AppTypography.textTheme.labelSmall
                                    ?.copyWith(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Instructions',
                    style: AppTypography.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _instructions,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Handle with care, call on arrival…',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Photo',
                    style: AppTypography.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickPhoto,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _photoPath != null
                              ? AppColors.success
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _photoPath != null
                                ? Icons.check_circle_rounded
                                : Icons.camera_alt_outlined,
                            color: _photoPath != null
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _photoPath == null
                                ? 'Add parcel photo'
                                : 'Photo added',
                            style: AppTypography.textTheme.labelLarge?.copyWith(
                              color: _photoPath != null
                                  ? AppColors.success
                                  : AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    if (fare != null) ...[
                      Row(
                        children: [
                          Text(
                            'Estimated fare',
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
                      const SizedBox(height: 12),
                    ],
                    BookingPrimaryButton(
                      label: 'Book now',
                      isLoading: _loading,
                      onPressed: _bookNow,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
