import 'package:flutter/material.dart';

import '../command/i_command.dart';

class BottomBarActions extends StatelessWidget {
  BottomBarActions({required this.actions, this.extendedActions});

  final List<BottomBarAction> actions;
  final Widget? extendedActions;

  @override
  Widget build(BuildContext context) {
    // ColorScheme _colors =
    //     Theme.of(context).buttonTheme.colorScheme ?? Theme.of(context).colorScheme;

    List<Widget> actionWidgets = [];
    if (extendedActions != null) actionWidgets.add(extendedActions!);
    actionWidgets.addAll(actions.where((element) => element.style != BottomBarActionStyle.missing));

    return BottomAppBar(
        child: Container(
          //color: _colors.surface,
          //padding: EdgeInsets.only(top: 4, bottom: 4),  // 8 caused overflow on Pixel 5
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: actionWidgets,
          ),
        )
    );
  }
}

enum BottomBarActionStyle { normal, highlighted, disabled, missing }

class BottomBarAction extends StatelessWidget {
  final ICommand? _command;
  final IconData _icon;
  final String _label;
  late final BottomBarActionStyle _style;

  BottomBarAction({required String label,
    required IconData icon,
    required ICommand? command,
    BottomBarActionStyle style = BottomBarActionStyle.normal})
      : _label = label,
        _icon = icon,
        _command = command {
    if (_command == null)
      style = BottomBarActionStyle.missing;
    else if (!_command.canExecute()) style = BottomBarActionStyle.disabled;
    _style = style;
  }

  BottomBarActionStyle get style => _style;

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme
        .of(context)
        .buttonTheme
        .colorScheme ?? Theme
        .of(context)
        .colorScheme;
    double dimFactor = 1;

    final List<Widget> content;
    switch (_style) {
      case BottomBarActionStyle.disabled:
        dimFactor = 0.15;
        content = [
          Icon(_icon, color: colorScheme.onSurfaceVariant),
          Text(_label, style: Theme
              .of(context)
              .textTheme
              .labelLarge)
        ];
        break;

      case BottomBarActionStyle.normal:
        content = [
          Icon(_icon, color: colorScheme.onSurfaceVariant),
          Text(_label, style: Theme
              .of(context)
              .textTheme
              .labelLarge)
        ];
        break;

      case BottomBarActionStyle.highlighted:
        content = [
          Icon(_icon, color: colorScheme.primary),
          Text(_label, style: Theme
              .of(context)
              .textTheme
              .labelLarge)
        ];
        break;
      case BottomBarActionStyle.missing:
        content = [];
        break;
    }

    return content.length == 0
        ? SizedBox(width: 1, height: 1)
        : InkWell(
        child: Opacity(
            opacity: dimFactor,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: content)),
        onTap: () async {
          if (_command != null && _command.canExecute()) await _command.executeAsync(context);
        });
  }
}
