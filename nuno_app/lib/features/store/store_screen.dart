import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/titled_panel.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/game_assets.dart';
import '../../data/models/enums.dart';
import '../../data/models/store_models.dart';
import '../auth/auth_controller.dart';
import 'cosmetics_provider.dart';

final storeItemsProvider = FutureProvider<List<StoreItem>>(
    (ref) => ref.watch(storeRepositoryProvider).getStore());

/// Cosmetics shop backed by GET /api/v1/store + /inventory.
class StoreScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const StoreScreen({super.key, this.embedded = false});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  CosmeticType? _filter;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(storeItemsProvider);
    final inventory = ref.watch(inventoryProvider).valueOrNull;
    final profile = ref.watch(currentProfileProvider);

    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.lg,
              AppDimens.sm,
              AppDimens.lg,
              AppDimens.md,
            ),
            child: Row(
              children: [
                if (!widget.embedded) ...[
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: AppDimens.md),
                ],
                Expanded(child: Text('Store', style: AppTextStyles.h2)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md,
                    vertical: AppDimens.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: AppDimens.brPill,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_rounded,
                          size: 16, color: AppColors.gold),
                      const SizedBox(width: 5),
                      Text(
                        Formatters.compact(
                          inventory?.coins ?? profile?.coins ?? 0,
                        ),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Category filter ─────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
              children: [
                _FilterChip(
                  label: 'All',
                  isActive: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final type in CosmeticType.values)
                  _FilterChip(
                    label: type.label,
                    isActive: _filter == type,
                    onTap: () => setState(() => _filter = type),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppDimens.lg),

          Expanded(
            child: items.when(
              loading: () => GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: AppDimens.sm,
                  crossAxisSpacing: AppDimens.sm,
                  childAspectRatio: 0.74,
                ),
                itemCount: 8,
                itemBuilder: (_, __) => const SkeletonBox(
                  height: 200,
                  borderRadius: AppDimens.brLg,
                ),
              ),
              error: (e, _) => ErrorStateView(
                message: e.toString(),
                onRetry: () => ref.invalidate(storeItemsProvider),
              ),
              data: (all) {
                final filtered = _filter == null
                    ? all
                    : all.where((i) => i.type == _filter).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Nothing here yet',
                    message: 'Check back soon for new items.',
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    ref.invalidate(storeItemsProvider);
                    ref.invalidate(inventoryProvider);
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.xl,
                      0,
                      AppDimens.xl,
                      AppDimens.sm,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: AppDimens.sm,
                      crossAxisSpacing: AppDimens.sm,
                      childAspectRatio: 0.74,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      // Free defaults are granted to everyone, so they read
                      // as owned even before anything is in the inventory.
                      final owned = item.isDefault ||
                          (inventory?.owns(item.itemId) ?? false);

                      return _StoreItemCard(
                        item: item,
                        owned: owned,
                        equipped:
                            inventory?.isEquipped(item.itemId) ?? false,
                        canAfford:
                            (inventory?.coins ?? profile?.coins ?? 0) >=
                                item.price,
                        onBuy: () => _purchase(item),
                        onEquip: () => _equip(item),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return ArtBackground(
        asset: Art.bgStore,
        vignette: false,
        child: content,
      );
    }

    return PanelScreen(
      title: 'Store',
      onBack: () => context.pop(),
      maxWidth: 700,
      padding: EdgeInsets.zero,
      child: SizedBox(height: 268, child: content),
    );
  }

  Future<void> _purchase(StoreItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Buy ${item.name}?'),
        content: Text(
          'This will cost ${item.price} ${item.currency.wire.toLowerCase()}.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTextStyles.body),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Buy',
              style: AppTextStyles.body.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(storeRepositoryProvider).purchase(item);
      ref.invalidate(inventoryProvider);
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      // The server equips a new purchase immediately, so say so rather than
      // leaving the player looking for a second step.
      AppSnack.show(context, '${item.name} unlocked and equipped');
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, e.toString());
    }
  }

  Future<void> _equip(StoreItem item) async {
    try {
      await ref.read(storeRepositoryProvider).equip(item);
      ref.invalidate(inventoryProvider);
      if (!mounted) return;
      AppSnack.show(context, '${item.name} equipped');
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, e.toString());
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.sm),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.primaryGradient : null,
            color: isActive ? null : AppColors.surface,
            borderRadius: AppDimens.brPill,
            border: Border.all(
              color: isActive
                  ? Colors.transparent
                  : AppColors.surfaceStroke,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreItemCard extends StatelessWidget {
  final StoreItem item;
  final bool owned;
  final bool equipped;
  final bool canAfford;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _StoreItemCard({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.canAfford,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final rarityColor = AppColors.forRarity(item.rarity.wire);

    return AppPanel(
      padding: EdgeInsets.zero,
      borderColor: rarityColor.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Preview ─────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        rarityColor.withValues(alpha: 0.30),
                        rarityColor.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDimens.radiusLg),
                    ),
                  ),
                  child: Center(
                    child: ArtImage(
                      // Card backs show their real skin; everything else
                      // falls back to the generic bundle art.
                      Art.cardSkin(item.itemId) ?? Art.shopBundle,
                      height: item.type == CosmeticType.cardBack ? 74 : 62,
                      fallback: Icon(
                        _iconFor(item.type),
                        size: 44,
                        color: rarityColor,
                      ),
                    ),
                  ),
                ),

                // Rarity badge.
                Positioned(
                  top: AppDimens.sm,
                  left: AppDimens.sm,
                  child: AppChip(
                    label: item.rarity.label.toUpperCase(),
                    color: rarityColor,
                    filled: true,
                    fontSize: 8,
                  ),
                ),

                // Discount / limited badges.
                if (item.isDiscounted)
                  Positioned(
                    top: AppDimens.sm,
                    right: AppDimens.sm,
                    child: AppChip(
                      label: '-${item.discountPercent}%',
                      color: AppColors.danger,
                      filled: true,
                      fontSize: 8,
                    ),
                  )
                else if (item.isLimited)
                  const Positioned(
                    top: AppDimens.sm,
                    right: AppDimens.sm,
                    child: AppChip(
                      label: 'LIMITED',
                      color: AppColors.warning,
                      filled: true,
                      fontSize: 8,
                    ),
                  ),

                if (equipped)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.18),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppDimens.radiusLg),
                        ),
                        border: Border.all(color: AppColors.success, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.check_circle_rounded,
                            size: 32, color: AppColors.success),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Info ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(fontSize: 14),
                ),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppDimens.sm),
                if (equipped)
                  const AppChip(
                    label: 'IN USE',
                    color: AppColors.success,
                    icon: Icons.check_rounded,
                  )
                else if (owned)
                  // Owned but not active. Without this the only thing a
                  // purchased item ever did was show a tick.
                  GestureDetector(
                    onTap: onEquip,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: AppDimens.brPill,
                        border: Border.all(color: AppColors.accent),
                      ),
                      child: Text(
                        'EQUIP',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Icon(
                        item.currency == CurrencyType.gems
                            ? Icons.diamond_rounded
                            : Icons.monetization_on_rounded,
                        size: 14,
                        color: item.currency == CurrencyType.gems
                            ? AppColors.rarityRare
                            : AppColors.gold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.price == 0
                            ? 'FREE'
                            : Formatters.number(item.price),
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: canAfford
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: canAfford ? onBuy : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.md,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient:
                                canAfford ? AppColors.primaryGradient : null,
                            color: canAfford ? null : AppColors.surfaceHigh,
                            borderRadius: AppDimens.brPill,
                          ),
                          child: Text(
                            canAfford ? 'BUY' : 'LOW',
                            style: AppTextStyles.caption.copyWith(
                              color: canAfford
                                  ? Colors.white
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(CosmeticType type) => switch (type) {
        CosmeticType.avatar => Icons.face_rounded,
        CosmeticType.cardBack => Icons.style_rounded,
        CosmeticType.cardTheme => Icons.palette_rounded,
        CosmeticType.cardAnimation => Icons.animation_rounded,
        CosmeticType.tableTheme => Icons.table_bar_rounded,
        CosmeticType.profileBanner => Icons.image_rounded,
        CosmeticType.badge => Icons.military_tech_rounded,
        CosmeticType.title => Icons.title_rounded,
        CosmeticType.emote => Icons.emoji_emotions_rounded,
        CosmeticType.voicePack => Icons.record_voice_over_rounded,
      };
}
