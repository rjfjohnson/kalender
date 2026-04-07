import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kalender/kalender_extensions.dart';
import 'package:kalender/src/models/calendar_events/calendar_event.dart';
import 'package:kalender/src/models/time_of_day_range.dart';

export 'package:kalender/kalender_extensions.dart';
export 'package:kalender/src/models/calendar_events/calendar_event.dart';
export 'package:kalender/src/models/time_of_day_range.dart';

/// Signature for the strategy that determines how DayEvents are laid out.
///
/// There are two built-in strategies:
///
///  * [overlapLayoutStrategy], which displays the tile over each other.
///
///  * [sideBySideLayoutStrategy], which displays the tiles next to each other.
///
typedef EventLayoutStrategy = EventLayoutDelegate Function(
  Iterable<CalendarEvent> events,
  InternalDateTime date,
  TimeOfDayRange timeOfDayRange,
  double heightPerMinute,
  double? minimumTileHeight,
  EventLayoutDelegateCache? cache,
  Location? location,
);

/// A [EventLayoutStrategy] that lays out the tiles on top of each other.
EventLayoutDelegate overlapLayoutStrategy(
  Iterable<CalendarEvent> events,
  InternalDateTime date,
  TimeOfDayRange timeOfDayRange,
  double heightPerMinute,
  double? minimumTileHeight,
  EventLayoutDelegateCache? cache,
  Location? location,
) {
  return OverlapLayoutDelegate(
    events: events,
    date: date,
    heightPerMinute: heightPerMinute,
    timeOfDayRange: timeOfDayRange,
    minimumTileHeight: minimumTileHeight,
    layoutCache: cache ?? EventLayoutDelegateCache(),
    location: location,
  );
}

/// A [EventLayoutStrategy] that lays out the tiles side by side.
EventLayoutDelegate sideBySideLayoutStrategy(
  Iterable<CalendarEvent> events,
  InternalDateTime date,
  TimeOfDayRange timeOfDayRange,
  double heightPerMinute,
  double? minimumTileHeight,
  EventLayoutDelegateCache? cache,
  Location? location,
) {
  return SideBySideLayoutDelegate(
    events: events,
    date: date,
    heightPerMinute: heightPerMinute,
    timeOfDayRange: timeOfDayRange,
    minimumTileHeight: minimumTileHeight,
    layoutCache: cache ?? EventLayoutDelegateCache(),
    location: location,
  );
}

/// A cache for [EventLayoutDelegate]s.
///
/// This is used to cache some values that are recalculated often.
/// What can/do we need to cache here ?
///
class EventLayoutDelegateCache {
  final Map<String, Map<int, VerticalLayoutData>> _dateCache = {};

  /// Generates a cache key based on the [date], [heightPerMinute], and [timeRange].
  String _generateCacheKey(DateTime date, double heightPerMinute, TimeOfDayRange timeRange) {
    return '${date.millisecondsSinceEpoch}_${heightPerMinute}_${timeRange.hashCode}';
  }

  /// Caches the vertical layout data for the given [date], [heightPerMinute], and [timeOfDayRange].
  Map<int, VerticalLayoutData>? getCache(DateTime date, double heightPerMinute, TimeOfDayRange timeOfDayRange) {
    final key = _generateCacheKey(date, heightPerMinute, timeOfDayRange);
    return _dateCache[key];
  }

  void setCache(DateTime date, double heightPerMinute, TimeOfDayRange timeRange, Map<int, VerticalLayoutData> cache) {
    final key = _generateCacheKey(date, heightPerMinute, timeRange);
    _dateCache[key] = cache;
  }

  void clearAll() => _dateCache.clear();
}

/// The base [MultiChildLayoutDelegate] class for laying out [CalendarEvent]s.
///
/// [EventLayoutDelegate]s are used to layout [CalendarEvent]s in  a [CustomMultiChildLayout].
///
/// The [EventLayoutDelegate] has some helper methods:
///
/// * [calculateHeight] - Calculates the size of an item along the time axis based on the [Duration] and [heightPerMinute] of the event.
/// * [calculateDistanceFromStart] - Calculates the distance from the start of the day to the start of the [CalendarEvent].
/// * [calculateVerticalLayoutData] - Calculates the start and end of each event along the time axis.
/// * [groupVerticalLayoutData] - Groups the [VerticalLayoutData] into cross-axis groups.
///
abstract class EventLayoutDelegate extends MultiChildLayoutDelegate {
  EventLayoutDelegate({
    required this.events,
    required this.heightPerMinute,
    required this.date,
    required this.location,
    required this.timeOfDayRange,
    required this.minimumTileHeight,
    required this.layoutCache,
    this.orientation = Axis.vertical,
  });

  /// The date for which the events are laid out.
  final InternalDateTime date;

  /// The location for which the events are laid out.
  final Location? location;

  /// The time of day range for which the events are laid out.
  final TimeOfDayRange timeOfDayRange;

  /// The list of events that will be laid out. (The order of these events are the same as the widget's)
  final Iterable<CalendarEvent> events;

  /// The height per minute of the current view.
  final double heightPerMinute;

  /// The minimum height of a tile.
  final double? minimumTileHeight;

  /// The cache for the [EventLayoutDelegate].
  final EventLayoutDelegateCache layoutCache;

  /// The orientation of the time axis.
  ///
  /// When [Axis.vertical], time flows top-to-bottom (default calendar behavior).
  /// When [Axis.horizontal], time flows left-to-right (EPG/timeline style).
  Axis orientation;

  /// Whether the time axis is horizontal.
  bool get isHorizontal => orientation == Axis.horizontal;

  /// Returns the size along the time axis.
  double timeAxisSize(Size size) => isHorizontal ? size.width : size.height;

  /// Returns the size along the cross axis (perpendicular to time).
  double crossAxisSize(Size size) => isHorizontal ? size.height : size.width;

  /// Sorts the [CalendarEvent]s.
  ///
  /// This is used to sort the events before passing them to the [EventLayoutDelegate].
  /// Override this method to provide custom sorting.
  List<CalendarEvent> sortEvents(Iterable<CalendarEvent> events);

  /// Calculates the size of an item along the time axis based on the [CalendarEvent.duration] and [heightPerMinute].
  double calculateHeight(CalendarEvent event) {
    final durationOnDate = event.internalRange(location: location).dateTimeRangeOnDate(date)?.duration ?? Duration.zero;
    final height = durationOnDate.inSeconds * heightPerMinute / 60;
    if (minimumTileHeight != null && height < minimumTileHeight!) {
      return minimumTileHeight!;
    }
    return height;
  }

  /// Calculates the distance from the start of the day to the start of the [event] along the time axis.
  double calculateDistanceFromStart(CalendarEvent event) {
    final eventStart = event.internalRange(location: location).dateTimeRangeOnDate(date)?.start ?? date.startOfDay;
    final dateStart = timeOfDayRange.start.toInternalDateTime(date);
    final difference = eventStart.difference(dateStart);
    final height = difference.inSeconds * heightPerMinute / 60;
    return height;
  }

  /// This is used to sort the vertical layout data after calculation.
  List<VerticalLayoutData> sortVerticalLayoutData(List<VerticalLayoutData> layoutData);

  /// Layout along the time axis.
  ///
  /// Calculates the start and end position of each event along the time axis,
  /// ensuring they are within the bounds of the widget.
  ///
  /// [size] - The size of the widget.
  List<VerticalLayoutData> calculateVerticalLayoutData(Size size) {
    final numberOfChildren = events.length;
    final currentCache = <int, VerticalLayoutData>{};
    final cache = layoutCache.getCache(date, heightPerMinute, timeOfDayRange);

    if (cache == null) {
      // If there is no cache, calculate the layout data for each event.
      for (var i = 0; i < numberOfChildren; i++) {
        final id = i;
        final event = events.elementAt(i);
        final eventHash = event.hashCode;
        currentCache[eventHash] = _calculateSingleEventLayout(id, size, event);
      }
    } else {
      // If there is a cache, use it to calculate the layout data for each event.
      for (var i = 0; i < numberOfChildren; i++) {
        final id = i;
        final event = events.elementAt(i);
        final eventHash = event.hashCode;

        final cached = cache[eventHash];
        if (cached == null) {
          currentCache[eventHash] = _calculateSingleEventLayout(id, size, event);
        } else {
          currentCache[eventHash] = cached.copyWith(id: id);
        }
      }
    }

    layoutCache.setCache(date, heightPerMinute, timeOfDayRange, currentCache);
    return sortVerticalLayoutData(currentCache.values.toList());
  }

  VerticalLayoutData _calculateSingleEventLayout(int id, Size size, CalendarEvent event) {
    var top = calculateDistanceFromStart(event);
    final height = calculateHeight(event);
    var bottom = top + height;

    // Use the time axis dimension for bounds checking.
    final axisSize = timeAxisSize(size);
    final overlap = axisSize - bottom;
    // Check if the event is outside the bounds of the widget.
    if (overlap.isNegative) {
      // Update the top and bottom to fit within the bounds.
      top += overlap;
      bottom += overlap;
    }

    // Round top and bottom to one decimal place.
    // This is to prevent floating point errors from causing issues with the layout.
    top = (top * 10).roundToDouble() / 10;
    bottom = (bottom * 10).roundToDouble() / 10;

    return VerticalLayoutData(id: id, top: top, bottom: bottom);
  }

  /// Groups the [VerticalLayoutData] into cross-axis groups.
  List<HorizontalGroupData> groupVerticalLayoutData(
    List<VerticalLayoutData> verticalLayoutData,
  ) {
    final horizontalGroups = <HorizontalGroupData>[];

    for (var i = 0; i < verticalLayoutData.length; i++) {
      final layoutData = verticalLayoutData.elementAt(i);
      final id = layoutData.id;
      final top = layoutData.top;
      final bottom = layoutData.bottom;

      // If the layout data is already in a group, skip it.
      if (horizontalGroups.any((group) => group.containsId(id))) continue;

      // Find the index of the group that overlaps with the layout data.
      final groupIndex = horizontalGroups.indexWhere((group) {
        return group.overlaps(top, bottom);
      });

      if (groupIndex != -1) {
        final group = horizontalGroups.elementAt(groupIndex);
        group.add(layoutData);
      } else {
        horizontalGroups.add(HorizontalGroupData(layoutData));
      }
    }

    return horizontalGroups;
  }

  /// Finds the longest chain of overlapping events using depth-first search.
  int findLongestChain(Iterable<VerticalLayoutData> verticalLayoutData) {
    // Early return if no events to process
    if (verticalLayoutData.isEmpty) return 0;

    final dataList = verticalLayoutData.toList();
    // Key: event index, Value: longest chain starting from that event
    final memo = <int, int>{};

    int depthFirstSearch(int currentIndex, Set<int> visited) {
      // If we've already calculated this, return cached result
      if (memo.containsKey(currentIndex)) return memo[currentIndex]!;
      var maxLength = 1;

      // Check all other events to see if they overlap with current event
      for (var i = 0; i < dataList.length; i++) {
        // Skip if it's the same event, already visited, or doesn't overlap
        if (i != currentIndex && !visited.contains(i) && dataList[currentIndex].overlaps(dataList[i])) {
          final newVisited = Set<int>.from(visited)..add(i);
          maxLength = max(maxLength, 1 + depthFirstSearch(i, newVisited));
        }
      }

      memo[currentIndex] = maxLength;
      return maxLength;
    }

    var maxChain = 1;
    for (var i = 0; i < dataList.length; i++) {
      maxChain = max(maxChain, depthFirstSearch(i, {i}));
    }

    return maxChain;
  }

  /// Creates a [BoxConstraints] for a tile given its time-axis extent and cross-axis extent.
  BoxConstraints tileConstraints({required double timeAxisExtent, required double crossAxisExtent}) {
    if (isHorizontal) {
      return BoxConstraints.tightFor(width: timeAxisExtent, height: crossAxisExtent);
    } else {
      return BoxConstraints.tightFor(width: crossAxisExtent, height: timeAxisExtent);
    }
  }

  /// Creates an [Offset] from time-axis position and cross-axis position.
  Offset tileOffset({required double timeAxisPosition, required double crossAxisPosition}) {
    if (isHorizontal) {
      return Offset(timeAxisPosition, crossAxisPosition);
    } else {
      return Offset(crossAxisPosition, timeAxisPosition);
    }
  }

  @override
  bool shouldRelayout(covariant EventLayoutDelegate oldDelegate) {
    return oldDelegate.events != events ||
        oldDelegate.heightPerMinute != heightPerMinute ||
        oldDelegate.timeOfDayRange != timeOfDayRange ||
        oldDelegate.date != date ||
        oldDelegate.minimumTileHeight != minimumTileHeight ||
        oldDelegate.location != location ||
        oldDelegate.orientation != orientation;
  }
}

/// The [OverlapLayoutDelegate] lays out [CalendarEvent]'s, by stacking them on top of one another.
class OverlapLayoutDelegate extends EventLayoutDelegate {
  OverlapLayoutDelegate({
    required super.events,
    required super.heightPerMinute,
    required super.date,
    required super.location,
    required super.timeOfDayRange,
    required super.minimumTileHeight,
    required super.layoutCache,
    super.orientation,
  });

  @override
  List<CalendarEvent> sortEvents(Iterable<CalendarEvent> events) {
    return events.toList()
      ..sort((a, b) => b.duration.compareTo(a.duration))
      ..sort(
        (a, b) => b.duration.compareTo(a.duration) == 0
            ? b.internalStart(location: location).compareTo(a.internalStart(location: location))
            : 0,
      );
  }

  @override
  void performLayout(Size size) {
    // Calculate the time-axis layout data.
    final verticalLayoutData = calculateVerticalLayoutData(size);

    // Group the layout data into cross-axis groups.
    final horizontalGroups = groupVerticalLayoutData(verticalLayoutData);

    final crossSize = crossAxisSize(size);

    for (var i = 0; i < horizontalGroups.length; i++) {
      final group = horizontalGroups.elementAt(i);

      final layoutData = <EventLayoutData>[];
      for (final data in group.verticalLayoutData) {
        // Check with how many already laid out events this event overlaps.
        final overlaps = layoutData.where((e) => e.overlaps(data));
        final numberOfOverlaps = overlaps.length + 1;

        double? lastWidth;
        if (overlaps.isNotEmpty) lastWidth = overlaps.reduce((e, f) => e.width <= f.width ? e : f).width;

        double width;
        double xOffset;
        if (lastWidth == null) {
          width = crossSize / numberOfOverlaps;
          xOffset = width * (numberOfOverlaps - 1);
        } else {
          width = lastWidth / 1.8;
          xOffset = crossSize - width;
        }

        // Layout the tile.
        layoutChild(data.id, tileConstraints(timeAxisExtent: data.height, crossAxisExtent: width));

        // Position the tile.
        positionChild(data.id, tileOffset(timeAxisPosition: data.top, crossAxisPosition: xOffset));

        // Add the layout data to the list.
        layoutData.add(EventLayoutData(left: xOffset, right: crossSize, verticalLayoutData: data));
      }
    }
  }

  @override
  List<VerticalLayoutData> sortVerticalLayoutData(List<VerticalLayoutData> layoutData) => layoutData;
}

/// The [SideBySideLayoutDelegate] lays out [CalendarEvent]'s next to one another.
class SideBySideLayoutDelegate extends EventLayoutDelegate {
  SideBySideLayoutDelegate({
    required super.events,
    required super.heightPerMinute,
    required super.date,
    required super.location,
    required super.timeOfDayRange,
    required super.minimumTileHeight,
    required super.layoutCache,
    super.orientation,
  });

  @override
  List<CalendarEvent> sortEvents(Iterable<CalendarEvent> events) => events.toList();
  @override
  List<VerticalLayoutData> sortVerticalLayoutData(List<VerticalLayoutData> layoutData) {
    return layoutData
      ..sort((a, b) {
        return a.top.compareTo(b.top) == 0 ? b.bottom.compareTo(a.bottom) : a.top.compareTo(b.top);
      });
  }

  @override
  void performLayout(Size size) {
    // Calculate the time-axis layout data.
    final verticalLayoutData = calculateVerticalLayoutData(size);

    // Group the layout data into cross-axis groups.
    final horizontalGroups = groupVerticalLayoutData(verticalLayoutData);

    final crossSize = crossAxisSize(size);

    for (var i = 0; i < horizontalGroups.length; i++) {
      final group = horizontalGroups.elementAt(i);
      final verticalLayoutData = group.verticalLayoutData
        ..sort(
          (a, b) => b.height.compareTo(a.height) == 0 ? b.top.compareTo(a.top) : b.height.compareTo(a.height),
        );

      final numberOfEvents = verticalLayoutData.length;
      final longest = findLongestChain(verticalLayoutData);
      final childCrossSize = crossSize / longest;

      final tiles = <int, Offset>{};
      final tileCrossSizes = <int, double>{};
      for (var i = 0; i < numberOfEvents; i++) {
        final data = verticalLayoutData.elementAt(i);
        final id = data.id;

        // Find the overlaps before the tile in the cross axis.
        final tilesBefore = verticalLayoutData.getRange(0, i);
        final overlapsBefore = tilesBefore.where((e) => e.overlaps(data));
        final lastOverlapBefore = overlapsBefore.lastOrNull;

        // Calculate the cross-axis offset of the tile.
        final double tileCrossOffset;
        if (lastOverlapBefore != null) {
          final prevOffset = isHorizontal ? tiles[lastOverlapBefore.id]!.dy : tiles[lastOverlapBefore.id]!.dx;
          tileCrossOffset = prevOffset + tileCrossSizes[lastOverlapBefore.id]!;
        } else {
          tileCrossOffset = childCrossSize * overlapsBefore.length;
        }

        // Find the overlaps after the tile in the cross axis.
        final tilesAfter = verticalLayoutData.getRange(i + 1, numberOfEvents);
        final overlapsAfter = tilesAfter.where((e) => e.overlaps(data)).toList();

        // Calculate the cross-axis size of the tile.
        var tileCrossSize = childCrossSize;
        if (overlapsAfter.isEmpty) {
          tileCrossSize = crossSize - tileCrossOffset;
        }

        // Layout the tile.
        layoutChild(
          id,
          tileConstraints(timeAxisExtent: data.height, crossAxisExtent: tileCrossSize),
        );

        tiles[id] = tileOffset(timeAxisPosition: data.top, crossAxisPosition: tileCrossOffset);
        tileCrossSizes[id] = tileCrossSize;
      }

      for (final tile in tiles.entries) {
        positionChild(tile.key, tile.value);
      }
    }
  }
}

/// This stores the time-axis layout data of a single [CalendarEvent].
///
/// [top] and [bottom] represent start and end positions along the time axis
/// (vertical for standard views, horizontal for rotated views).
class VerticalLayoutData {
  /// The id of the event.
  final int id;

  /// The start position along the time axis.
  final double top;

  /// The end position along the time axis.
  final double bottom;

  VerticalLayoutData({required this.id, required this.top, required this.bottom});

  /// The extent along the time axis.
  double get height => bottom - top;

  /// Checks if this [VerticalLayoutData] overlaps with [other].
  bool overlaps(VerticalLayoutData other) {
    final isInside = other.top > top && other.bottom < bottom;

    final overlapTop = other.top <= top && other.bottom > top;

    final overlapBottom = other.top < bottom && other.bottom >= bottom;

    final outside = other.top <= top && other.bottom >= bottom;

    return isInside || overlapTop || overlapBottom || outside;
  }

  @override
  String toString() => 'id: $id, top: $top, bottom: $bottom';

  /// Creates a copy of this [VerticalLayoutData] with a new [id].
  VerticalLayoutData copyWith({int? id}) {
    return VerticalLayoutData(id: id ?? this.id, top: top, bottom: bottom);
  }
}

/// This stores the final layout data of a single [CalendarEvent].
class EventLayoutData {
  /// The start of the event in the cross axis.
  final double left;

  /// The end of the event in the cross axis.
  final double right;

  /// The time-axis layout data of the event.
  final VerticalLayoutData verticalLayoutData;

  EventLayoutData({
    required this.left,
    required this.right,
    required this.verticalLayoutData,
  });

  /// The cross-axis extent of the event.
  double get width => right - left;

  /// The id of the event.
  int get id => verticalLayoutData.id;

  /// Checks if this [EventLayoutData] overlaps with [other].
  bool overlaps(VerticalLayoutData other) => verticalLayoutData.overlaps(other);
}

/// This stores cross-axis data [top] and [bottom] for a group of [VerticalLayoutData].
class HorizontalGroupData {
  final List<VerticalLayoutData> verticalLayoutData = [];

  /// The start of the group along the time axis.
  double top = double.infinity;

  /// The end of the group along the time axis.
  double bottom = double.negativeInfinity;

  HorizontalGroupData(VerticalLayoutData initialData) {
    verticalLayoutData.add(initialData);
    top = initialData.top;
    bottom = initialData.bottom;
  }

  /// Adds the [layoutData] to the [HorizontalGroupData].
  void add(VerticalLayoutData layoutData) {
    verticalLayoutData.add(layoutData);
    top = layoutData.top < top ? layoutData.top : top;
    bottom = layoutData.bottom > bottom ? layoutData.bottom : bottom;
  }

  /// Whether the [HorizontalGroupData] overlaps with the given [top] and [bottom].
  bool overlaps(double top, double bottom) {
    final isInside = top > this.top && bottom < this.bottom;
    final overlapsTop = top <= this.top && bottom > this.top;
    final overlapsBottom = top < this.bottom && bottom >= this.bottom;
    final isOutside = top <= this.top && bottom >= this.bottom;

    return isInside || overlapsTop || overlapsBottom || isOutside;
  }

  /// Whether the [HorizontalGroupData] contains the [id].
  bool containsId(int id) => verticalLayoutData.any((layoutData) => layoutData.id == id);

  @override
  String toString() => 'top: $top, bottom: $bottom';
}
