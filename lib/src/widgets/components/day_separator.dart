import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:kalender/src/models/providers/calendar_provider.dart';

/// The day separator builder.
///
/// The [style] is used to style the day separator.
typedef DaySeparatorBuilder = Widget Function(
  DaySeparatorStyle? style,
);

/// The style for the [DaySeparator] widget.
class DaySeparatorStyle {
  /// The [Color] of the day separator.
  final Color? color;

  /// The width of the day separator.
  final double? width;

  /// The top indent of the day separator.
  final double? topIndent;

  /// The bottom indent of the day separator.
  final double? bottomIndent;

  const DaySeparatorStyle({
    this.color,
    this.width,
    this.topIndent,
    this.bottomIndent,
  });
}

/// A widget that displays a separator between days.
class DaySeparator extends StatelessWidget {
  final DaySeparatorStyle? style;
  const DaySeparator({super.key, this.style});
  static DaySeparator builder(DaySeparatorStyle? style) {
    return DaySeparator(style: style);
  }

  static Widget fromContext(BuildContext context) {
    final daySeparatorStyle = context.components.multiDayComponentStyles.bodyStyles.daySeparatorStyle;
    final components = context.components.multiDayComponents.bodyComponents;
    return components.daySeparator.call(daySeparatorStyle);
  }

  @override
  Widget build(BuildContext context) {
    final viewController = context.calendarController.viewController;
    final isHorizontal = viewController is MultiDayViewController &&
        viewController.viewConfiguration.isHorizontal;

    final color = style?.color ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    final thickness = style?.width ?? 1;
    final topIndent = style?.topIndent ?? 0;
    final bottomIndent = style?.bottomIndent ?? 0;

    if (isHorizontal) {
      // Horizontal separator between day rows
      return Container(
        margin: EdgeInsets.only(left: topIndent, right: bottomIndent),
        height: thickness,
        color: color,
      );
    } else {
      // Vertical separator between day columns (default)
      return Container(
        margin: EdgeInsetsDirectional.only(start: topIndent, end: bottomIndent),
        width: thickness,
        color: color,
      );
    }
  }
}
