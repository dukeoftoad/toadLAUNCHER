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

import '../../core/device/device_bridge.dart';
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
  Size? _lastReportedSize;

  @override
  Widget build(BuildContext context) {
    final widget = this.widget.widget;

    return LayoutBuilder(
      builder: (context, constraints) {
        // PLT-07 — tell the real AppWidgetHostView its new size (dp) so
        // responsive widgets re-render. Reported once per change, after
        // layout: options updates are not free.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _maybeReportSize(constraints),
        );
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
      },
    );
  }

  void _maybeReportSize(BoxConstraints constraints) {
    final id = widget.widget.appWidgetId;
    if (id == null || !constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      return;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = Size(constraints.maxWidth / dpr, constraints.maxHeight / dpr);
    final last = _lastReportedSize;
    if (last != null &&
        (last.width - size.width).abs() < 4 &&
        (last.height - size.height).abs() < 4) {
      return; // sub-4dp jitter is noise
    }
    _lastReportedSize = size;
    DeviceBridge().resizeHostedWidget(
      appWidgetId: id,
      widthDp: size.width.round(),
      heightDp: size.height.round(),
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
