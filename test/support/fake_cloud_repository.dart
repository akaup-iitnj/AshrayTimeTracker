import 'dart:async';

import 'package:hourly_time_tracker/src/app_store.dart';
import 'package:hourly_time_tracker/src/cloud_repository.dart';
import 'package:hourly_time_tracker/src/local_repository.dart';
import 'package:hourly_time_tracker/src/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCloudRepository implements CloudRepository {
  FakeCloudRepository({
    this.signedIn = true,
    this.userId = 'user-1',
    this.email = 'test@example.com',
    this.fetchStarted,
    this.fetchGate,
    this.pushStarted,
    this.pushGate,
    this.remote = const CloudSnapshot(
      categories: [],
      entries: [],
      settings: null,
    ),
  });

  bool signedIn;
  String userId;
  String email;
  CloudSnapshot remote;
  CloudSnapshot? pushed;
  Object? fetchError;
  Object? pushError;
  Completer<void>? fetchStarted;
  Completer<void>? fetchGate;
  Completer<void>? pushStarted;
  Completer<void>? pushGate;
  int fetchCount = 0;
  int pushCount = 0;

  @override
  Stream<void> get authChanges => const Stream<void>.empty();

  @override
  String? get currentUserEmail => signedIn ? email : null;

  @override
  String? get currentUserId => signedIn ? userId : null;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<CloudSnapshot> fetchSnapshot() async {
    fetchCount++;
    final started = fetchStarted;
    if (started != null && !started.isCompleted) started.complete();
    final gate = fetchGate;
    if (gate != null) await gate.future;
    if (fetchError case final error?) throw error;
    return remote;
  }

  @override
  Future<void> pushSnapshot(CloudSnapshot snapshot) async {
    pushCount++;
    final started = pushStarted;
    if (started != null && !started.isCompleted) started.complete();
    final gate = pushGate;
    if (gate != null) await gate.future;
    if (pushError case final error?) throw error;
    pushed = snapshot;
    remote = snapshot;
  }

  @override
  Future<void> signIn(String email, String password) async {
    signedIn = true;
    this.email = email.trim();
  }

  int googleSignIns = 0;

  @override
  Future<void> signInWithGoogle() async {
    googleSignIns++;
    signedIn = true;
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
  }

  @override
  Future<CloudAuthResult> signUp(String email, String password) async {
    signedIn = true;
    this.email = email.trim();
    return const CloudAuthResult(needsEmailConfirmation: false);
  }
}

Future<AppStore> createStore(
  FakeCloudRepository cloud, {
  Map<String, Object> initialPreferences = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(initialPreferences);
  final preferences = await SharedPreferences.getInstance();
  return AppStore.load(
    LocalRepository(preferences),
    NoopReminderScheduler(),
    cloud,
  );
}
