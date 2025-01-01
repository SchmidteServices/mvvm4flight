import 'dart:core';

import 'package:flutter/material.dart';

import 'i_command.dart';

class RelayCommand implements ICommand {
  final void Function(Exception e)? _onError;
  final bool Function()? _canExecute;
  final Future<void> Function(BuildContext context) _actionAsync;

  RelayCommand(
    this._actionAsync, {
    bool Function()? canExecute,
    void Function(Exception e)? onError,
  })  : _canExecute = canExecute,
        _onError = onError;

  bool canExecute() => _canExecute != null ? _canExecute() : true;

  Future<void> executeAsync(BuildContext context, [dynamic p]) async {
    try {
      if (canExecute()) await _actionAsync(context);
    } on Exception catch (e) {
      if (_onError == null) {
        assert(false, e.toString());
        throw e;
      }
      _onError(e);
    }
  }
}
