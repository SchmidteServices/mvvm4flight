import 'package:flutter/foundation.dart';

import '../enums.dart';
import 'viewmodel_base.dart';

mixin DataLoader<TArgs> on ViewModelBase {
  void init({required TArgs args}) {
    if (state == ViewModelState.ready) {
      state = ViewModelState.loading;
      initAsync(args).then((_) {
        _args = args;
        state = ViewModelState.asyncLoadCompleted;
        notifyListeners();
      });
    } else if (state == ViewModelState.asyncLoadCompleted) {
      state = ViewModelState.ready;
    } else if (state == ViewModelState.loading) {
      //return;
    }
  }

  TArgs? _args;

  TArgs? get args => _args;

  @protected
  Future<void> initAsync(TArgs args);
}

mixin DataLoaderN on ViewModelBase {
  void init() {
    state =ViewModelState.loading;
    initAsync().then((_) {
    state =ViewModelState.ready;
      notifyListeners();
    });
  }

  @protected
  Future<void> initAsync();
}

/// Extend a ViewModelBased to support data binding.
///
/// Data binging is used to pass data from a View to a ViewModel:
/// pass or bing data to the ViewModel.
@deprecated
mixin DataBinder<TData> on ViewModelBase {
  void bindData(TData model) {
    if (_data != null && model == _data) return;
    if (_data != null) onContextChanging(model);
    _data = model;
    if ((this is LazyLoad)) (this as LazyLoad).lazyLoad();
  }

  TData? _data;

  TData get data => _data!;

  @protected
  void onContextChanging(TData newData) {}
}

@deprecated
mixin LazyLoad on ViewModelBase {
  void lazyLoad() {
    state = ViewModelState.loading;
    onLoadAsync().then((_) {
    state = ViewModelState.ready;
      notifyListeners();
    });
  }

  /// Start asynchronous initialization of the ViewModel.
  /// Once this is completed the state is [ViewModelState.ready].
  ///
  /// Call this method from the View:
  /// ```
  /// Widget build(BuildContext context) => ViewModelBuilder<ContactListViewModel>.reactive(
  ///       viewModelBuilder: () => new ContactListViewModel(),
  ///       onModelReady: (viewModel) => viewModel.lazyLoad(),
  ///       builder: _buildPage);
  /// ```

  /// Provide an asynchronous initialisation functionality.
  ///
  /// [onLoadAsync] is started during [startLazyLoad] and
  /// no explicit call of asynchronous initialisation is necessary.
  @protected
  Future<void> onLoadAsync();
}
