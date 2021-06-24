import 'package:async_redux/async_redux.dart';
import 'package:logging/logging.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// Connects a [Logger] to the Redux Store.
/// Every action that is dispatched will be logged to the Logger, along with the new State
/// that was created as a result of the action reaching your Store's reducer.
///
/// By default, this class does not print anything to your console or to a web
/// service, such as Fabric or Sentry. It simply logs entries to a Logger instance.
/// You can then listen to the [Logger.onRecord] Stream, and print to the
/// console or send these actions to a web service.
///
/// Example: To print actions to the console as they are dispatched:
///
///     var store = Store(
///       initialValue: 0,
///       actionObservers: [Log.printer()]);
///
/// Example: If you only want to log actions to a Logger, use the default constructor.
///
///     // Create your own Logger and pass it to the Observer.
///     final logger = new Logger("Redux Logger");
///     final stateObserver = Log(logger: logger);
///
///     final store = new AnyStore<int>(
///       initialState: 0,
///       stateObserver: [stateObserver]);
///
///     // Note: One quirk about listening to a logger instance is that you're
///     // actually listening to the Singleton instance of *all* loggers.
///     logger.onRecord
///       // Filter down to [LogRecord]s sent to your logger instance
///       .where((record) => record.loggerName == logger.name)
///       // Print them out (or do something more interesting!)
///       .listen((LogRecord) => print(LogRecord));
///
class Log<St, Environment> implements ActionObserver<St, Environment> {
  //
  final Logger logger;

  /// The log Level at which the actions will be recorded
  final Level level;

  /// A function that formats the String for printing
  final MessageFormatter<St, Environment> formatter;

  /// Logs actions to the given Logger, and does not print anything to the console.
  Log({
    Logger? logger,
    this.level = Level.INFO,
    this.formatter = singleLineFormatter,
  }) : logger = logger ?? Logger("Log");

  /// Logs actions to the console.
  factory Log.printer({
    Logger? logger,
    Level level = Level.INFO,
    MessageFormatter<St, Environment> formatter = singleLineFormatter,
  }) {
    final log = Log(logger: logger, level: level, formatter: formatter);
    log.logger.onRecord //
        .where((record) => record.loggerName == log.logger.name)
        .listen(print);
    return log;
  }

  /// A very simple formatter that writes only the action.
  static String verySimpleFormatter(
    dynamic state,
    ReduxAction action,
    bool ini,
    int dispatchCount,
    DateTime timestamp,
  ) =>
      "$action ${ini ? 'INI' : 'END'}";

  /// A simple formatter that puts all data on one line.
  static String singleLineFormatter(
    dynamic state,
    ReduxAction action,
    bool? ini,
    int dispatchCount,
    DateTime timestamp,
  ) {
    return "{$action, St: $state, ts: ${new DateTime.now()}}";
  }

  /// A formatter that puts each attribute on it's own line.
  static String multiLineFormatter(
    dynamic state,
    ReduxAction action,
    bool ini,
    int dispatchCount,
    DateTime timestamp,
  ) {
    return "{\n"
        "  $dispatchCount) $action,\n"
        "  St: $state,\n"
        "  Timestamp: ${new DateTime.now()}\n"
        "}";
  }

  @override
  void observe(ReduxAction<St, Environment> action, int dispatchCount, {required bool ini}) {
    logger.log(
      level,
      formatter(null, action, ini, dispatchCount, new DateTime.now()),
    );
  }
}

// /////////////////////////////////////////////////////////////////////////////

/// A function that formats the message that will be logged:
///
///   final log = Log(formatter: onlyLogActionFormatter);
///   var store = new Store(initialState: 0, actionObservers:[log], stateObservers: [...]);
///
typedef MessageFormatter<St, Environment> = String Function(
  St? state,
  ReduxAction<St, Environment> action,
  bool ini,
  int dispatchCount,
  DateTime timestamp,
);
