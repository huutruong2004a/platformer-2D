// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RoomNotifier)
final roomProvider = RoomNotifierProvider._();

final class RoomNotifierProvider
    extends $NotifierProvider<RoomNotifier, RoomState> {
  RoomNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roomProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roomNotifierHash();

  @$internal
  @override
  RoomNotifier create() => RoomNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomState>(value),
    );
  }
}

String _$roomNotifierHash() => r'736c6e6cbce83bb95e768207b541b324f30f7215';

abstract class _$RoomNotifier extends $Notifier<RoomState> {
  RoomState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<RoomState, RoomState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RoomState, RoomState>,
              RoomState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
