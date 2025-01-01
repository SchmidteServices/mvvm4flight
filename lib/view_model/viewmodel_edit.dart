import 'dart:async';

import 'package:flutter/material.dart';

import '../mf4flight.dart';

/// A [ViewModelBase] implementation that supports editable data.
///
/// Protected method start with "on.." when they are called from this super/base class.
/// on-methods should be implemented in the inheriting class but not called directly.
/// You may place them in a "// region ViewModel implementation"
abstract class ViewModelEdit<TArgs> extends ViewModelBase<TArgs> {
  @protected
  ViewModelEdit() : super() {
    _createCommands();
  }

  Future<ViewCloseBehaviour> askSaveAsync(BuildContext context) async {
    DialogResultYesNoCancel dialogResult = await Dialog2.showQueryDialogAsync(
        context, "Änderungen erkannt!", "Sollen die Änderungen gespeichert werden?",
        actions: [Dialog2.noButton, Dialog2.yesButton], cancelButton: true);

    switch (dialogResult) {
      case DialogResultYesNoCancel.yes:
        return ViewCloseBehaviour.saveDataClose;
      case DialogResultYesNoCancel.no:
        return ViewCloseBehaviour.discardDataClose;
      case DialogResultYesNoCancel.cancel:
        return ViewCloseBehaviour.cancelClose;
    }
  }

  /// Check whether the current view can be closed.
  ///
  /// There are three options how a view can be closed:
  /// [CloseViewRequestSource]
  /// *Back Button*: In that case there is no default behaviour, it is not
  /// generally defined how the view should behave.
  /// In such case *the view's* [decisionIfDirtyAsync] will be called and ask for a
  /// decision. You may display a pop-up and aks the user what to do, or simply
  /// return a [ViewCloseBehaviour]. The default for [decisionIfDirtyAsync] is
  /// [ViewCloseBehaviour.discardDataClose] so that dirty data will be discarded
  /// when the Back-Button is used.
  /// decisionIfDirty: () async => await queryViewCloseDialog(context)
  ///
  /// *closeView Command*: The [saveAndCloseViewCommand] tries to save data and
  /// then close the view. Of course, if saving fails the view remains open
  /// showing the error src.api.v1.messages.
  ///
  /// *cancelView Command*: The [cancelEditCloseViewCommand] closes the view without
  /// saving dirty data - discard data.
  Future<bool> viewCanCloseAsync(BuildContext context,
      {Future<ViewCloseBehaviour> Function()? decisionIfDirtyAsync}) async {
    bool canCloseView;
    switch (closeViewRequestSource) {
      case CloseViewRequestSource.cancelAndCloseViewCommand:
        canCloseView = true;
        break;

      case CloseViewRequestSource.backButton:
        if (isDirtyViewModel()) {
          // Back Button and data has changed!
          if (validateControls()) {
            // Controls are ok to be saved
            // Data is dirty, the user has to make a decision
            ViewCloseBehaviour decision;
            if (decisionIfDirtyAsync != null)
              decision = await decisionIfDirtyAsync();
            else
              decision = await askSaveAsync(context);
            switch (decision) {
              case ViewCloseBehaviour.discardDataClose:
                canCloseView = true;
                break;
              case ViewCloseBehaviour.cancelClose:
                canCloseView = false;
                break;
              case ViewCloseBehaviour.saveDataClose:
                canCloseView = await saveAsync();
                break;
            }
          } else {
            // Back Button and Controls are not ok
            // Expect user want to discard edits
            canCloseView = true;
          }
        } else {
          // Data not dirty and we can close the view
          canCloseView = true;
        }
        break;

      case CloseViewRequestSource.pushView:
      case CloseViewRequestSource.saveAndCloseViewCommand:
        canCloseView = await saveAsync();
        break;
      default:
        throw "upps";
    }

    // Important: After the close request has been evaluated,
    // we must reset the source for subsequent calls.
    closeViewRequestSource = CloseViewRequestSource.backButton;
    return canCloseView;
  }

  /// Checks if the current view is dirty (contains changes).
  bool isDirtyViewModel() => state == ViewModelState.ready ? onIsDirty() : false;

  @protected
  bool onIsDirty() => true;

  /// Validate the view controls to ensure the view's data can be saved.
  ///
  /// Use the [errors] collection to collect all validation errors.
  /// ````dart
  /// void onValidateControls() {
  ///    if (salutation.length < 4 || Helper.nameInvalidChars.hasMatch(salutation))
  ///      errors.addError('salutation', 'Bitte geben sie ei..
  ///  }
  /// ```
  /// In the example, the error is filed under the key 'salutation'.
  /// You can access these errors in a [InputDecoration.errorText] property
  /// using the [getFieldError] method.
  /// ```dart
  /// child: new TextField(
  ///   controller: viewModel.salutationController,
  ///   decoration: InputDecoration(
  ///   labelText: 'Anrede',
  ///   errorText: viewModel.getFieldError('salutation'),
  /// ))),
  /// ```
  @protected
  void onValidateControls(ViewErrors errors) {}

  /// Get and persist the view's data.
  ///
  /// When this method is called the view is considered to be
  /// valid (passed the [onValidateControls] checks).
  /// In case the view's data is a [DatabaseRecord] the record fields
  /// are updated with the data from the view and then the record is saved
  /// to the data_model. To avoid updating the data_model with unchanged data use
  /// the [DatabaseRecord.trackChanges] pattern.
  ///
  /// ```dart
  /// /// The record that was used to populate the view.
  /// FriendRecord get _original => _args.item;
  ///
  /// @override
  /// Future onSaveAsync() async {
  ///   // Track Changes Pattern
  ///   _original.trackChanges(new FriendRecord());
  ///   _viewToRecord(_original);
  ///   await _c.friends.saveAsync(_original);
  ///   showSnackBar('${_original.toString()} gespeichert!');
  ///   serviceProvider<SyncRequestService>().triggerSyncRequest();
  /// }
  /// ```
  @protected
  Future<void> onSaveAsync();

  /// Validate all controls [onValidateControls]
  /// and save the view's data [onSaveAsync].
  Future<bool> saveAsync() async {
    logger.finest(">saveAsync");
    if (!validateControls()) return false;

    // Do not call isDirty before validating the controls.
    // IsDirty requires a valid DB record from the view,
    // and if validation fails, the record is not valid.
    if (isDirtyViewModel()) await onSaveAsync();
    return true;
  }

  // region Error messages

  /// Get a list with the view model's errors.
  final ViewErrors _viewErrors = new ViewErrors();

  bool validateControls() {
    _viewErrors.clear();
    onValidateControls(_viewErrors);
    return _viewErrors.isEmpty;
  }

  /// Get the view's error or null.
  ///
  /// The viewError contains the exception message, when
  /// the @viewModelEdit is saved (@onsaveAsync).
  String? getViewError() => _viewErrors.getFirst('view')?.errorMessage;

  void setViewError(String errorMessage) {
    logger.severe(errorMessage);
    _viewErrors.addError('view', errorMessage);
    // for now it is not expected the view has errors
    assert(false, 'saveAsync: $errorMessage');
  }

  String? getFieldError(String fieldKey) => _viewErrors.getFirst(fieldKey)?.errorMessage;
  
  /// Get the error message for a specified field
  /// or null on case of no error
  // endregion

  // region Commands

  late ICommand saveAndCloseViewCommand;

  void _createCommands() {
    saveAndCloseViewCommand = new RelayCommand((context) async {
      closeViewRequestSource = CloseViewRequestSource.saveAndCloseViewCommand;
      await navigator.maybePop();
      notifyListeners();
    }/*,canExecute: () => dataLoaded && isDirtyViewModel()*/);
  }

  // endregion
  /// Request view close (navigator.maybePop()) with
  /// [CloseViewRequestSource.saveAndCloseViewCommand].
  ///
  /// See [viewCanCloseAsync] if and how the view will be closed.
}
