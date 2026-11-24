/// The real-widget renderer — v0.11's answer to "a clock drawn inside
/// Flutter is not the same as hosting a genuine Android home-screen
/// widget".
///
/// Wraps [PlatformViewLink] + hybrid composition so the actual
/// AppWidgetHostView (inflated by MainActivity's `toad-widget-host`
/// factory) is embedded in the Flutter tree, live-updating and
/// touch-reactive exactly like a stock launcher's widget.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import 'placed_widgets.dart' show widgetZoneHeight;

const String kToadWidgetViewType = 'toad-widget-host';

/// One hosted Android widget — a genuine AppWidgetHostView.
class AndroidHostedWidgetView extends StatefulWidget {
  const AndroidHostedWidgetView({super.key, required this.widget});

  final PlacedWidget widget;

  @override
  State<AndroidHostedWidgetView> createState() =>
      _AndroidHostedWidgetViewState();
}

class _AndroidHostedWidgetViewState extends State<AndroidHostedWidgetView> {
  @override
  Widget build(BuildContext context) {
    final widget = this.widget.widget;

    return SizedBox(
      height: widgetZoneHeight(widget.h),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ToadRadii.card),
          child: PlatformViewLink(
            viewType: kToadWidgetViewType,
            surfaceFactory: (context, controller) => AndroidViewSurface(
              controller: controller as ExpensiveAndroidViewController,
              gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            ),
            onCreatePlatformView: (params) {
              return PlatformViewsService.initExpensiveAndroidView(
                id: params.id,
                viewType: kToadWidgetViewType,
                layoutDirection: Directionality.of(context),
                creationParams: <String, Object?>{
                  'appWidgetId': widget.appWidgetId,
                  'providerId': widget.providerId,
                },
                creationParamsCodec: const StandardMessageCodec(),
                onFocus: () => params.onFocusChanged(true),
              )
                ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
                ..create();
            },
          ),
        ),
      ),
    );
  }
}

/// Placeholder card for the picker / tests / non-Android surfaces — the
/// honest frame that says what would be hosted here.
class HostedWidgetPlaceholder extends StatelessWidget {
  const HostedWidgetPlaceholder({
    super.key,
    required this.label,
    required this.h,
  });

  final String label;
  final int h;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    return SizedBox(
      height: widgetZoneHeight(h),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: palette.surface.a * 0.85),
            borderRadius: BorderRadius.circular(ToadRadii.card),
            border: Border.all(color: palette.hairline),
          ),
          child: Text(
            'real Android widget · $label',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: ToadType.hand(14, color: palette.ink),
          ),
        ),
      ),
    );
  }
}
