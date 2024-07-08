import 'package:fluffychat/pangea/enum/bar_chart_view_enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

class AnalyticsViewButton extends StatelessWidget {
  final BarChartViewSelection value;
  final void Function(BarChartViewSelection) onChange;
  final List<BarChartViewSelection> enabledViews;
  const AnalyticsViewButton({
    super.key,
    required this.value,
    required this.onChange,
    this.enabledViews = const [
      BarChartViewSelection.messages,
      BarChartViewSelection.vocab,
      BarChartViewSelection.grammar,
    ],
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BarChartViewSelection>(
      tooltip: L10n.of(context)!.changeAnalyticsView,
      initialValue: value,
      onSelected: (BarChartViewSelection? view) {
        if (view == null) {
          debugPrint("when is view null?");
          return;
        }
        onChange(view);
      },
      itemBuilder: (BuildContext context) => enabledViews
          .map<PopupMenuEntry<BarChartViewSelection>>(
              (BarChartViewSelection view) {
        return PopupMenuItem<BarChartViewSelection>(
          value: view,
          child: Text(view.string(context)),
        );
      }).toList(),
      child: TextButton.icon(
        label: Text(
          value.string(context),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        icon: Icon(
          value.icon,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: null,
      ),
    );
  }
}
