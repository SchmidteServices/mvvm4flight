import 'package:flutter/material.dart';

import 'i_command.dart';

typedef Future<void> CommandActionAsync(BuildContext context, dynamic args);


class RelayPCommand implements ICommand {
  final bool Function()? _canExecute;
  final CommandActionAsync _actionAsync;

  @protected
  RelayPCommand( this._actionAsync, {bool Function()? canExecute}) : _canExecute = canExecute ;

  bool canExecute() => _canExecute != null ? _canExecute() : true;

  Future executeAsync(BuildContext context, [dynamic args]) async {
    if( canExecute()) await _actionAsync(context, args);
  }
}
