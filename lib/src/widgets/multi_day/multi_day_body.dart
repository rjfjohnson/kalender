import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:kalender/src/models/providers/calendar_provider.dart';
import 'package:kalender/src/models/view_configurations/page_index_calculator.dart';
import 'package:kalender/src/widgets/drag_targets/vertical_drag_target.dart';
import 'package:kalender/src/widgets/draggable/day_draggable.dart';
import 'package:kalender/src/widgets/events_widgets/day_events_widget.dart';
import 'package:kalender/src/widgets/internal_components/time_indicator_positioner.dart';
import 'package:kalender/src/widgets/internal_components/timeline_sizer.dart';
import 'package:linked_pageview/linked_pageview.dart';

/// This widget is used to display a multi-day body.
///
/// Supports both vertical (default) and horizontal orientations via [MultiDayViewConfiguration.orientation].
class MultiDayBody extends StatelessWidget {
  /// The [MultiDayBodyConfiguration] that will be used by the [MultiDayBody].
  final MultiDayBodyConfiguration? configuration;

  /// Creates a new [MultiDayBody].
  const MultiDayBody({
    super.key,
    this.configuration,
  });

  /// The key used to identify the [SingleChildScrollView] of the [MultiDayBody].
  static const singleChildScrollViewKey = ValueKey('singleChildScrollViewKey');

  @override
  Widget build(BuildContext context) {
    final controller = context.calendarController;

    assert(
      controller.viewController is MultiDayViewController,
      'The CalendarController\'s $ViewController needs to be a $MultiDayViewController',
    );

    final viewController = controller.viewController as MultiDayViewController;
    final viewConfiguration = viewController.viewConfiguration;
    final timeOfDayRange = viewConfiguration.timeOfDayRange;
    final isHorizontal = viewConfiguration.isHorizontal;

    final configuration = this.configuration ?? const MultiDayBodyConfiguration();

    // Calculate the total size along the time axis.
    final timeAxisSize = context.heightPerMinute * timeOfDayRange.duration.inMinutes;

    return Stack(
      children: [
        Scrollbar(
          controller: viewController.scrollController,
          child: SingleChildScrollView(
            key: singleChildScrollViewKey,
            controller: viewController.scrollController,
            scrollDirection: isHorizontal ? Axis.horizontal : Axis.vertical,
            physics: configuration.scrollPhysics,
            child: _buildScrollContent(
              context,
              viewController: viewController,
              configuration: configuration,
              timeOfDayRange: timeOfDayRange,
              timeAxisSize: timeAxisSize,
              isHorizontal: isHorizontal,
            ),
          ),
        ),
        // The DragTarget is positioned on top of the content.
        Positioned.fill(
          child: _buildDragTargetOverlay(
            context,
            controller: controller,
            viewController: viewController,
            viewConfiguration: viewConfiguration,
            configuration: configuration,
            isHorizontal: isHorizontal,
          ),
        ),
      ],
    );
  }

  Widget _buildScrollContent(
    BuildContext context, {
    required MultiDayViewController viewController,
    required MultiDayBodyConfiguration configuration,
    required TimeOfDayRange timeOfDayRange,
    required double timeAxisSize,
    required bool isHorizontal,
  }) {
    final timeline = TimeLine.fromContext(context, timeOfDayRange);
    final hourLines = HourLines.fromContext(context, timeOfDayRange);

    final pageArea = Expanded(
      child: Stack(
        children: [
          Positioned.fill(child: hourLines),
          Positioned.fill(
            child: MultiDayPage(
              eventsController: context.eventsController,
              viewController: viewController,
              configuration: configuration,
              pageHeight: timeAxisSize,
              location: context.location,
            ),
          ),
          PositionedTimeIndicator(
            viewController: viewController,
            initialPage: viewController.initialPage,
          ),
        ],
      ),
    );

    if (isHorizontal) {
      // Horizontal: timeline on top, days stack vertically, time scrolls horizontally
      return SizedBox(
        width: timeAxisSize,
        child: Column(
          children: [
            SizedBox(width: timeAxisSize, child: timeline),
            pageArea,
          ],
        ),
      );
    } else {
      // Vertical (default): timeline on left, days spread horizontally, time scrolls vertically
      return SizedBox(
        height: timeAxisSize,
        child: Row(
          children: [
            SizedBox(height: timeAxisSize, child: timeline),
            pageArea,
          ],
        ),
      );
    }
  }

  Widget _buildDragTargetOverlay(
    BuildContext context, {
    required CalendarController controller,
    required MultiDayViewController viewController,
    required MultiDayViewConfiguration viewConfiguration,
    required MultiDayBodyConfiguration configuration,
    required bool isHorizontal,
  }) {
    final sizer = const TimelineSizer(child: SizedBox());

    Widget buildTarget(BoxConstraints constraints) {
      if (isHorizontal) {
        final pageWidth = constraints.maxWidth;
        final pageHeight = constraints.maxHeight;
        final dayHeight = pageHeight / viewConfiguration.numberOfDays;

        return SizedBox(
          height: pageHeight,
          child: VerticalDragTarget(
            controller: controller,
            viewController: viewController,
            configuration: configuration,
            pageWidth: pageWidth,
            dayWidth: dayHeight,
            viewPortHeight: pageWidth,
            snapping: context.snappingNotifier,
          ),
        );
      } else {
        final pageHeight = constraints.maxHeight;
        final pageWidth = constraints.maxWidth;
        final dayWidth = pageWidth / viewConfiguration.numberOfDays;

        return SizedBox(
          height: pageHeight,
          child: VerticalDragTarget(
            controller: controller,
            viewController: viewController,
            configuration: configuration,
            pageWidth: pageWidth,
            dayWidth: dayWidth,
            viewPortHeight: pageHeight,
            snapping: context.snappingNotifier,
          ),
        );
      }
    }

    if (isHorizontal) {
      return Column(
        children: [
          sizer,
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) => buildTarget(constraints)),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          sizer,
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) => buildTarget(constraints)),
          ),
        ],
      );
    }
  }
}

class MultiDayPage extends StatefulWidget {
  final EventsController eventsController;
  final MultiDayViewController viewController;
  final MultiDayBodyConfiguration configuration;
  final double pageHeight;
  final Location? location;

  const MultiDayPage({
    super.key,
    required this.eventsController,
    required this.viewController,
    required this.configuration,
    required this.pageHeight,
    required this.location,
  });

  static const contentKey = Key('MultiDayPage-Content');

  @override
  State<MultiDayPage> createState() => _MultiDayPageState();
}

class _MultiDayPageState extends State<MultiDayPage> {
  PageIndexCalculator get _pageNavigation => widget.viewController.viewConfiguration.pageIndexCalculator;

  @override
  void initState() {
    super.initState();
    _initialPage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.eventsController.addListener(_currentPage);
    });
  }

  @override
  void didUpdateWidget(covariant MultiDayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) setState(() {});
  }

  @override
  void dispose() {
    widget.eventsController.removeListener(_currentPage);
    super.dispose();
  }

  void _initialPage() => _updateVisibleEvents(widget.viewController.initialPage, widget.location);
  void _currentPage() =>
      _updateVisibleEvents(widget.viewController.pageController.page?.round() ?? 0, context.location);

  void _updateVisibleEvents(int index, Location? location) {
    final events = widget.eventsController.eventsFromDateTimeRange(
      _pageNavigation.dateTimeRangeFromIndex(index, location),
      includeDayEvents: true,
      includeMultiDayEvents: widget.configuration.showMultiDayEvents,
      location: location,
    );
    widget.viewController.visibleEvents.value = events.toSet();
  }

  int get _numberOfDays => widget.viewController.viewConfiguration.numberOfDays;
  bool get _isFreeScroll => widget.viewController.viewConfiguration.type == MultiDayViewType.freeScroll;
  bool get _isHorizontal => widget.viewController.viewConfiguration.isHorizontal;

  @override
  Widget build(BuildContext context) {
    return LinkedPageView.builder(
      key: ObjectKey(widget.viewController.pageController),
      padEnds: false,
      controller: widget.viewController.pageController,
      itemCount: widget.viewController.numberOfPages,
      physics: widget.configuration.pageScrollPhysics,
      onPageChanged: (index) {
        final visibleRange = _pageNavigation.dateTimeRangeFromIndex(index, context.location);
        final range = _isFreeScroll
            ? InternalDateTimeRange(
                start: visibleRange.start,
                end: visibleRange.start.add(Duration(days: widget.viewController.viewConfiguration.numberOfDays)),
              )
            : visibleRange;
        final controller = context.calendarController;
        controller.internalDateTimeRange.value = range;
        _updateVisibleEvents(index, context.location);
        final callbacks = context.callbacks;
        callbacks?.onPageChanged?.call(controller.visibleDateTimeRange.value!);
      },
      itemBuilder: (context, index) {
        final visibleRange = _pageNavigation.dateTimeRangeFromIndex(index, context.location);

        // Build day separators along the appropriate axis.
        final separatorCount = _isFreeScroll ? 1 : _numberOfDays + 1;
        final separators = _isHorizontal
            ? Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(separatorCount, (_) => DaySeparator.fromContext(context)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(separatorCount, (_) => DaySeparator.fromContext(context)),
              );

        return Stack(
          key: MultiDayPage.contentKey,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: separators),
            Positioned.fill(
              child: DayDraggable(
                visibleDateTimeRange: visibleRange,
                timeOfDayRange: widget.viewController.viewConfiguration.timeOfDayRange,
                pageHeight: widget.pageHeight,
              ),
            ),
            Positioned.fill(
              child: MultiDayEventsRow(
                configuration: widget.configuration,
                internalRange: visibleRange,
                viewController: widget.viewController,
              ),
            ),
          ],
        );
      },
    );
  }
}
