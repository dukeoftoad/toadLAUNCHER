library;

import 'package:material_ui/material_ui.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/toad_tokens.dart';
import '../../../core/theme/toad_theme.dart';

class MemoriesCard extends StatelessWidget {
  const MemoriesCard({super.key, required this.data, this.onOpen});

  final MemoryCardData data;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(ToadRadii.card),
          border: Border.all(color: palette.hairline, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x403C3214),
              offset: Offset(0, 8),
              blurRadius: 22,
              spreadRadius: -12,
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(ToadRadii.card),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        data.title,
                        style: ToadType.caveat(
                          ToadMetrics.memoryTitleSize,
                          color: palette.accentInk,
                          height: 1.0,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        data.meta,
                        style: ToadType.inter(
                          11,
                          color: palette.ink.withValues(
                            alpha: palette.ink.a * 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      for (var i = 0; i < data.photoCount; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _MemoryPhoto(
                            gradient:
                                AppIconGradients.memoryPhotos[i %
                                    AppIconGradients.memoryPhotos.length],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accentWash,
                      borderRadius: BorderRadius.circular(ToadRadii.pill),
                    ),
                    child: Text(
                      'Open toadGALLERY →',
                      style: ToadType.hand(13.5, color: palette.accentInk),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryPhoto extends StatelessWidget {
  const _MemoryPhoto({required this.gradient});

  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ToadMetrics.memoryPhotoHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ToadMetrics.memoryPhotoRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
            stops: const [0, 0.7],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ToadMetrics.memoryPhotoRadius),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 26,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.28),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
