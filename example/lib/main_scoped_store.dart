import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

late AnyStore<AppState, AppEnvironment> store;
late AnyStore<UserState, UserEnvironment> userStore;

/// This example shows a counter, a text description, and a button.
/// When the button is tapped, the counter will increment synchronously,
/// while an async process downloads some text description that relates
/// to the counter number (using the NumberAPI: http://numbersapi.com).
///
/// While the async process is running, a reddish modal barrier will prevent
/// the user from tapping the button. The model barrier is removed even if
/// the async process ends with an error, which can be simulated by turning
/// off the internet connection (putting the phone in airplane mode).
///
/// Note: This example uses http. It was configured to work in Android, debug mode only.
/// If you use iOS, please see:
/// https://flutter.dev/docs/release/breaking-changes/network-policy-ios-android
///
void main() {
  var state = AppState.initialState();
  var environment = AppEnvironment();
  store = Store<AppState, AppEnvironment>(initialState: state, environment: environment);

  userStore = store.scope<UserState, UserEnvironment>(
    state: (state) => state.userState,
    integrateState: (state, userState) => state.copy(userState: userState),
    environment: (_) => UserEnvironment()
  );

  Future.delayed(const Duration(seconds: 3), () {
    userStore.dispatch(UserLoginAction());
  });
  

  // Can also observe userStore, to respond to i.e. requests to log out!
  // userStore.onChange.listen { if state.requestLogOut == true ... }


  runApp(MyApp());
}

///////////////////////////////////////////////////////////////////////////////

class UserState {
  final bool loggedIn;

  UserState({required this.loggedIn});

  UserState copy({bool? loggedIn}) => UserState(loggedIn: loggedIn ?? this.loggedIn);
}

class UserEnvironment {}

class UserLoginAction extends ReduxAction<UserState, UserEnvironment> {

  @override
  void before() {
    print("BEFORE login");
  }

  @override
  UserState reduce() => state.copy(loggedIn: true);

  @override
  void after() {
    print("AFTER login");
  }
}

/// The app state, which in this case is a counter, a description, and a waiting flag.
class AppState {
  final int? counter;
  final String? description;
  final bool? waiting;
  final UserState userState;

  AppState({this.counter, this.description, this.waiting, required this.userState});

  AppState copy({int? counter, String? description, bool? waiting, UserState? userState}) => AppState(
        counter: counter ?? this.counter,
        description: description ?? this.description,
        waiting: waiting ?? this.waiting,
        userState: userState ?? this.userState
      );

  static AppState initialState() => AppState(
    counter: 0,
     description: "",
      waiting: false,
       userState: UserState(loggedIn: false)
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          description == other.description &&
          waiting == other.waiting;

  @override
  int get hashCode => counter.hashCode ^ description.hashCode ^ waiting.hashCode;
}

class AppEnvironment {}

///////////////////////////////////////////////////////////////////////////////

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState, AppEnvironment>(
      store: store,
      child: MaterialApp(
        home: MyHomePageConnector(),
      ));
}

///////////////////////////////////////////////////////////////////////////////

/// This action increments the counter by 1,
/// and then gets some description text relating to the new counter number.
class IncrementAndGetDescriptionAction extends ReduxAction<AppState, AppEnvironment> {
  //
  // Async reducer.
  // To make it async we simply return Future<AppState> instead of AppState.
  @override
  Future<AppState> reduce() async {
    // First, we increment the counter, synchronously.
    dispatch(IncrementAction(amount: 1));

    // Then, we start and wait for some asynchronous process.
    String description = await read(Uri.http("numbersapi.com","${state.counter}"));

    // After we get the response, we can modify the state with it,
    // without having to dispatch another action.
    return state.copy(description: description);
  }

  // This adds a modal barrier while the async process is running.
  @override
  void before() => dispatch(BarrierAction(true));

  // This removes the modal barrier when the async process ends,
  // even if there was some error in the process.
  // You can test it by turning off the internet connection.
  @override
  void after() => dispatch(BarrierAction(false));
}

///////////////////////////////////////////////////////////////////////////////

class BarrierAction extends ReduxAction<AppState, AppEnvironment> {
  final bool waiting;

  BarrierAction(this.waiting);

  @override
  AppState reduce() {
    return state.copy(waiting: waiting);
  }
}

///////////////////////////////////////////////////////////////////////////////

/// This action increments the counter by [amount]].
class IncrementAction extends ReduxAction<AppState, AppEnvironment> {
  final int amount;

  IncrementAction({required this.amount});

  // Synchronous reducer.
  @override
  AppState reduce() => state.copy(counter: state.counter! + amount);
}

///////////////////////////////////////////////////////////////////////////////

/// This widget is a connector. It connects the store to "dumb-widget".
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AppEnvironment, ViewModel>(
      vm: () => Factory(this),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        counter: vm.counter,
        description: vm.description,
        onIncrement: vm.onIncrement,
        waiting: vm.waiting,
        loggedIn: vm.loggedIn,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class Factory extends VmFactory<AppState, AppEnvironment, MyHomePageConnector> {
  Factory(widget) : super(widget);

  @override
  ViewModel fromStore() => ViewModel(
        counter: state.counter,
        description: state.description,
        waiting: state.waiting,
        onIncrement: () => dispatch(IncrementAndGetDescriptionAction()),
        loggedIn: state.userState.loggedIn
      );
}

/// The view-model holds the part of the Store state the dumb-widget needs.
class ViewModel extends Vm {
  final int? counter;
  final String? description;
  final bool? waiting;  
  final VoidCallback onIncrement;
  final bool loggedIn;

  ViewModel({
    required this.counter,
    required this.description,
    required this.waiting,
    required this.onIncrement,
    required this.loggedIn,
  }) : super(equals: [counter!, description!, waiting!, loggedIn]);
}

///////////////////////////////////////////////////////////////////////////////

class MyHomePage extends StatelessWidget {
  final int? counter;
  final String? description;
  final bool? waiting;
  final bool? loggedIn;
  final VoidCallback? onIncrement;

  MyHomePage({
    Key? key,
    this.counter,
    this.description,
    this.waiting,
    this.loggedIn,
    this.onIncrement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Before and After Example')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('You have pushed the button this many times:'),
                Text('$counter', style: const TextStyle(fontSize: 30)),
                Text(
                  description!,
                  style: const TextStyle(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                Text('You are ${loggedIn == true ? "logged in" : "NOT logged in"}'),
                
                StoreProvider(store: userStore, child: 
                Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.red)),
                  padding: const EdgeInsets.all(16),
                  child: StoreConnector<UserState, UserEnvironment, String>(
                    converter: (store) => 'According to user store, you are ${store.state.loggedIn == true ? "logged in" : "NOT logged in"}',
                    builder: (context, model) => Text(model),
                  )
                ,))

              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: onIncrement,
            child: const Icon(Icons.add),
          ),
        ),
        if (waiting!) ModalBarrier(color: Colors.red.withOpacity(0.4)),
      ],
    );
  }
}
