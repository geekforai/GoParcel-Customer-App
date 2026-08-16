import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/places_service.dart';
import '../../../../core/widgets/gp_places_field.dart';
import '../../../../core/widgets/gp_primary_button.dart';
import '../../../../core/widgets/gp_states.dart';
import '../../../../domain/entities/customer.dart';

class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  List<SavedAddress> _addresses = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await ref.read(customerRepositoryProvider).getSavedAddresses();
    if (!mounted) return;
    result.when(
      success: (list) => setState(() {
        _addresses = list;
        _loading = false;
      }),
      failure: (_) => setState(() => _loading = false),
    );
  }

  Future<void> _openAddSheet() async {
    final labelCtrl = TextEditingController(text: 'Home');
    final addressCtrl = TextEditingController();
    PlaceDetails? selected;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add address', style: AppTypography.textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'Home / Office',
                ),
              ),
              const SizedBox(height: 10),
              GpPlacesField(
                controller: addressCtrl,
                label: 'Search address',
                hintText: 'Type area, landmark, or full address',
                onPlaceSelected: (p) => selected = p,
              ),
              const SizedBox(height: 14),
              GpPrimaryButton(
                label: 'Save locally',
                onPressed: () {
                  if (addressCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && mounted) {
      final label = labelCtrl.text.trim().isEmpty ? 'Saved' : labelCtrl.text.trim();
      final address = selected?.address.isNotEmpty == true
          ? selected!.address
          : addressCtrl.text.trim();
      setState(() {
        _addresses = [
          ..._addresses,
          SavedAddress(
            id: 'local-${DateTime.now().millisecondsSinceEpoch}',
            label: label,
            address: address,
          ),
        ];
      });
    }

    labelCtrl.dispose();
    addressCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const GpLoadingState()
          : _addresses.isEmpty
              ? const GpEmptyState(
                  title: 'No saved addresses',
                  subtitle: 'Tap + to search and add with Places',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: _addresses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final a = _addresses[i];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      leading: const Icon(
                        Icons.place_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        a.label,
                        style: AppTypography.textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        a.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: a.isDefault
                          ? Text(
                              'Default',
                              style: AppTypography.textTheme.labelMedium
                                  ?.copyWith(color: AppColors.primary),
                            )
                          : null,
                    );
                  },
                ),
    );
  }
}
