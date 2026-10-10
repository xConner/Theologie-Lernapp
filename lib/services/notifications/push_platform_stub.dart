import 'push_platform.dart';

/// Außerhalb des Browsers gibt es keinen Web-Push.
class PlatformPush implements PushPlatform {
  @override
  PushSupport get support => PushSupport.unsupported;

  @override
  PushPermission get permission => PushPermission.notAsked;

  @override
  PushDevice get device => PushDevice.desktop;

  @override
  bool get isBrave => false;

  @override
  String? get timeZone => null;

  @override
  Future<PushPermission> requestPermission() async => PushPermission.notAsked;

  @override
  Future<PushSubscriptionInfo?> currentSubscription(String publicKey) async {
    return null;
  }

  @override
  Future<PushSubscriptionInfo> subscribe(String publicKey) {
    throw UnsupportedError("Push wird auf dieser Plattform nicht unterstützt.");
  }

  @override
  Future<void> unsubscribe() async {}

  @override
  String? takeLaunchLink() => null;

  @override
  Stream<String> get links => const Stream.empty();
}
