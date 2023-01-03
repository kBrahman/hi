import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hi/bloc/bloc_main.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/util.dart';

class BlockedWidget extends StatelessWidget {
  final MainBloc _mainBloc;

  const BlockedWidget(this._mainBloc, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snap) {
        return Scaffold(
            appBar: AppBar(title: const Text('hi')),
            body: Center(
                child: snap.connectionState == ConnectionState.done
                    ? _blocked(context, snap.data!)
                    : const CircularProgressIndicator()));
      });

  Widget _blocked(BuildContext context, SharedPreferences sp) {
    final blockTime = sp.getInt(BLOCK_TIME)!;
    final blockPeriod = BlockPeriod.values[sp.getInt(BLOCK_PERIOD_INDEX)!];
    final l10n = AppLocalizations.of(context);
    final code = Localizations.localeOf(context).languageCode;
    final unblockTime = DateTime.fromMillisecondsSinceEpoch(blockTime + getMilliseconds(blockPeriod));
    final day = DateFormat.yMMMMd(code).format(unblockTime);
    final time = DateFormat.Hm(code).format(unblockTime.add(const Duration(minutes: 1)));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(l10n?.account_blocked ?? 'Your account is blocked.', style: bold20),
      Text((l10n?.block_period ?? 'Block period:') + _getPeriod(blockPeriod, l10n), style: bold20),
      if (blockPeriod != BlockPeriod.FOREVER)
        Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: Text(l10n?.unblock_time(day, time) ?? 'Your account will be unblocked on $day at $time',
                textAlign: TextAlign.center)),
      ElevatedButton(onPressed: () => _mainBloc.ctr.add(Cmd.REFRESH), child: Text(l10n?.refresh ?? 'Refresh'))
    ]);
  }

  String _getPeriod(BlockPeriod blockPeriod, AppLocalizations? l10n) {
    switch (blockPeriod) {
      case BlockPeriod.WEEK:
        return l10n?.week ?? 'one week';
      case BlockPeriod.MONTH:
        return l10n?.month ?? 'one month';
      case BlockPeriod.QUARTER:
        return l10n?.three_months ?? 'three months';
      case BlockPeriod.SEMI:
        return l10n?.six_months ?? 'six months';
      case BlockPeriod.YEAR:
        return l10n?.year ?? 'one year';
      case BlockPeriod.FOREVER:
        return l10n?.forever ?? 'forever';
      case BlockPeriod.TEST:
        return 'test';
      default:
        throw UnimplementedError();
    }
  }
}
