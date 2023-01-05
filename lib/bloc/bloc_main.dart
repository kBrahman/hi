// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:hi/bloc/bloc_base.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../util/util.dart';

class MainBloc extends BaseBloc<UiState, Cmd> {
  static const _TAG = 'MainBloc';

  MainBloc() {
    hiLog(_TAG, 'main bloc');
    platform.invokeMethod('checkConn').then((value) => BaseBloc.connectedToInet = value);
    stream = _getStream();
  }

  Stream<UiState> _getStream() async* {
    final sp = await SharedPreferences.getInstance();
    yield _getState(sp);
    await for (final cmd in ctr.stream)
      switch (cmd) {
        case Cmd.REFRESH:
          yield UiState.LOADING;
          yield _getState(sp);
          break;
        case Cmd.BLOCK:
          yield UiState.BLOCKED;
          break;
        case Cmd.SIGN_IN:
          yield UiState.SIGN_IN;
          break;
        case Cmd.PROFILE:
          yield UiState.PROFILE;
      }
  }

  UiState _getState(SharedPreferences sp) => sp.getBool(IS_BLOCKED) == true && !_blockExpired(sp)
      ? UiState.BLOCKED
      : !(sp.getBool(TERMS_ACCEPTED) ?? false)
          ? UiState.TERMS
          : sp.getBool(IS_SIGNED_IN) == true
              ? UiState.PROFILE
              : UiState.SIGN_IN;

  bool _blockExpired(SharedPreferences sp) {
    final blockTime = sp.getInt(BLOCK_TIME)!;
    final index = sp.getInt(BLOCK_PERIOD_INDEX)!;
    hiLog(_TAG, 'block time: $blockTime, index: $index');
    final blockPeriod = getMilliseconds(BlockPeriod.values[index]);
    if (DateTime.now().isBefore(DateTime.fromMillisecondsSinceEpoch(blockTime + blockPeriod))) return false;
    sp.remove(IS_BLOCKED);
    sp.remove(BLOCK_TIME);
    sp.remove(BLOCK_PERIOD_INDEX);
    return true;
  }

  @override
  onLost() {

  }
}

enum Cmd { REFRESH, BLOCK, SIGN_IN, PROFILE }
