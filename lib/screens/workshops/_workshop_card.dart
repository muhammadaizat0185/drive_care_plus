import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../models/workshop.dart';
import '../../widgets/ui/ui.dart';

/// Single Browse-tab workshop card for the redesigned `workshop_map_screen`.
///
/// Implements Tasks 9.6, 9.7 (specialty overflow), 9.8 (heart favorite
/// optimistic toggle), and 9.10 (card body tap → detail bottom sheet).
///
/// Layout (top to bottom):
///   * leading thumbnail surface with the workshop's first photo letter
///     (image fetch is deferred — see TODO at the bottom of this file);
///   * name + heart favorite icon row;
///   * rating badge + review-count + open/closed status row;
///   * distance + price-range row;
///   * specialty chip row showing `min(2, specialties.length)` chips with
///     a `+N more` overflow label when `specialties.length > 2`
///     (Property 13);
///   * footer row with `Navigate` (secondary) and `Book Now` (gradient)
///     buttons.
///
/// Visual constants come from the design-token extensions on
/// `Theme.of(context)`; no hex colors, spacing, radii, or typography
/// literals from the Token_Sets are inlined (Requirement 3.11).
class WorkshopCard extends StatelessWidget {
  final Workshop workshop;
  final List<String> specialties;
  final String priceRange;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onNavigate;
  final VoidCallback? onBook;

  const WorkshopCard({
    super.key,
    required this.workshop,
    this.specialties = const <String>[],
    this.priceRange = '\$\$',
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
    this.onNavigate,
    this.onBook,
  });

  // Number of specialty chips rendered inline before the overflow label
  // takes over. Locked at 2 by Requirement 7.5 / Property 13.
  static const int _specialtyVisibleLimit = 2;

  // Visual diameter of the thumbnail's letter avatar. Card-local sizing
  // detail, not a Token_Set member.
  static const double _thumbDiameter = 64.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final bool isOpen = workshop.isOpenNow ?? true;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ---- Header row: thumbnail, name, heart -----------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Thumbnail(
                colors: colors,
                typography: typography,
                size: _thumbDiameter,
                letter: workshop.name.isNotEmpty
                    ? workshop.name[0].toUpperCase()
                    : '?',
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      workshop.name,
                      style: typography.title.copyWith(
                        color: colors.foreground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacing.xs),
                    Row(
                      children: <Widget>[
                        AppBadge(
                          text: '★ ${workshop.rating.toStringAsFixed(1)}',
                          kind: BadgeKind.brand,
                        ),
                        SizedBox(width: spacing.sm),
                        Text(
                          '(${workshop.reviewCount})',
                          style: typography.label.copyWith(
                            color: colors.foreground
                                .withValues(alpha: colors.surfaceProminent),
                          ),
                        ),
                        SizedBox(width: spacing.sm),
                        AppBadge(
                          text: isOpen ? 'Open' : 'Closed',
                          kind: isOpen
                              ? BadgeKind.success
                              : BadgeKind.error,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppIconButton(
                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                onPressed: onFavoriteToggle,
                semanticsLabel: isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                color: isFavorite ? colors.error : null,
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          // ---- Distance + price-range row -------------------------
          Row(
            children: <Widget>[
              Icon(
                Icons.location_on_outlined,
                size: typography.body.fontSize,
                color: colors.foreground
                    .withValues(alpha: colors.surfaceProminent),
              ),
              SizedBox(width: spacing.xs),
              Text(
                workshop.distance ?? '—',
                style: typography.body.copyWith(color: colors.foreground),
              ),
              SizedBox(width: spacing.lg),
              Text(
                priceRange,
                style: typography.body.copyWith(
                  color: colors.emerald600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          // ---- Specialty chip row + overflow label ----------------
          _SpecialtyRow(
            specialties: specialties,
            visibleLimit: _specialtyVisibleLimit,
          ),
          SizedBox(height: spacing.md),
          // ---- Footer: Navigate + Book Now ------------------------
          Row(
            children: <Widget>[
              Expanded(
                child: AppSecondaryButton(
                  label: 'Navigate',
                  onPressed: onNavigate,
                  icon: Icons.directions,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppGradientButton(
                  label: 'Book Now',
                  onPressed: onBook,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Specialty chip row + overflow label. Extracted as a top-level widget so
/// the pure render predicate behind Property 13 (workshop card specialty
/// overflow) can be exercised in isolation by the property test in
/// Task 9.7 without mounting a full `WorkshopCard`.
class _SpecialtyRow extends StatelessWidget {
  const _SpecialtyRow({
    required this.specialties,
    required this.visibleLimit,
  });

  final List<String> specialties;
  final int visibleLimit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final int total = specialties.length;
    final int visible = total < visibleLimit ? total : visibleLimit;
    final int overflow = total - visible;

    final List<Widget> children = <Widget>[];
    for (int i = 0; i < visible; i++) {
      if (i > 0) {
        children.add(SizedBox(width: spacing.xs));
      }
      children.add(AppBadge(text: specialties[i]));
    }
    if (overflow > 0) {
      children.add(SizedBox(width: spacing.xs));
      children.add(
        Text(
          '+$overflow more',
          style: typography.label.copyWith(
            color: colors.foreground
                .withValues(alpha: colors.surfaceProminent),
          ),
          // The overflow text serves as the property-13 indicator so the
          // PBT can find it by string. Using a key would couple the test
          // to an internal id; matching by exact text keeps the contract
          // visible to the user too.
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 0,
      runSpacing: spacing.xs,
      children: children,
    );
  }
}

/// Thumbnail surface used as a placeholder when the upstream Google Places
/// photo lookup is not yet wired through. Renders a square card with the
/// workshop's first letter centered inside.
///
/// TODO(figma-ui-redesign Task 9.6): swap the letter avatar for an
/// `Image.network(workshop.photos.first)` once the Places photo URL
/// resolution is plumbed through `GoogleMapsService`. The redesigned
/// layout reserves the slot — this placeholder keeps the visual contract
/// stable until the photo fetch lands.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.colors,
    required this.typography,
    required this.size,
    required this.letter,
  });

  final AppColorsExt colors;
  final AppTypographyExt typography;
  final double size;
  final String letter;

  @override
  Widget build(BuildContext context) {
    final AppRadiiExt radii = Theme.of(context).extension<AppRadiiExt>()!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radii.medium),
        gradient: LinearGradient(
          colors: <Color>[colors.emerald500, colors.teal400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        letter,
        style: typography.headline.copyWith(color: Colors.white),
      ),
    );
  }
}
