import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import '../models/analytics/chart_analytics_model.dart';

enum TimeSpan { day, week, month, sixmonths, year, forever }

extension TimeSpanFunctions on TimeSpan {
  String string(BuildContext context) {
    switch (this) {
      case TimeSpan.day:
        return L10n.of(context)!.oneday;
      case TimeSpan.week:
        return L10n.of(context)!.oneweek;
      case TimeSpan.month:
        return L10n.of(context)!.onemonth;
      case TimeSpan.sixmonths:
        return L10n.of(context)!.sixmonth;
      case TimeSpan.year:
        return L10n.of(context)!.oneyear;
      default:
        return "Invalid time span";
    }
  }

  int get numberOfIntervals {
    switch (this) {
      case TimeSpan.day:
        return 24;
      case TimeSpan.week:
        return 7;
      case TimeSpan.month:
        return DateTime.now().month == 2 ? 26 : 28;
      case TimeSpan.sixmonths:
        return 6;
      case TimeSpan.year:
        return 12;
      default:
        return 0;
    }
  }

  Duration timeAgo(int index) {
    switch (this) {
      case TimeSpan.day:
        return Duration(hours: index);
      case TimeSpan.week:
      case TimeSpan.month:
        return Duration(days: index);
      case TimeSpan.year:
      case TimeSpan.sixmonths:
        return Duration(days: index * 32);
      default:
        return Duration.zero;
    }
  }

  DateTime get cutOffDate {
    switch (this) {
      case TimeSpan.day:
        return DateTime.now().subtract(Duration(hours: numberOfIntervals));
      case TimeSpan.week:
        return DateTime.now().subtract(Duration(days: numberOfIntervals));
      case TimeSpan.month:
        //PTODO - get onee month agoo
        return DateTime.now().subtract(Duration(days: numberOfIntervals));
      case TimeSpan.sixmonths:
        //PTODO - get six months ago
        return DateTime.now().subtract(Duration(days: numberOfIntervals * 30));
      case TimeSpan.year:
        return DateTime.now().subtract(const Duration(days: 365));
      case TimeSpan.forever:
        return DateTime(2020);
    }
  }

  String getMapKey(DateTime date) {
    switch (this) {
      case TimeSpan.day:
        return date.hour.toString();
      case TimeSpan.week:
        return date.weekday.toString();
      case TimeSpan.month:
        return date.day.toString();
      case TimeSpan.sixmonths:
      case TimeSpan.year:
        return date.month.toString();
      default:
        return "Invalid time span";
    }
  }

  /// Note: end is same as start!!
  Map<String, TimeSeriesInterval> get emptyIntervals {
    final DateTime now = DateTime.now();
    final List<int> numbers =
        List.generate(numberOfIntervals, (index) => index);
    final Map<String, TimeSeriesInterval> map = {};

    // debugger(when: kDebugMode);
    for (final index in numbers) {
      final timeAgos = timeAgo(index);
      final DateTime end = now.subtract(timeAgos);
      // debugger(when: end.isBefore(now.subtract(const Duration(days: 30))));
      final String mapKey = getMapKey(end);
      // debugger(when: mapKey.toString() == "5");
      map[mapKey] = TimeSeriesInterval(
        start: end,
        end: end,
        totals: TimeSeriesTotals.empty,
      );
    }
    // debugger(when: kDebugMode);
    return map;
  }
}
