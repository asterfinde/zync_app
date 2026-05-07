import 'package:get_it/get_it.dart';
import 'modules/external_module.dart';
import 'modules/identity_module.dart';
import 'modules/circle_module.dart';
import 'modules/presence_module.dart';
import 'modules/geofencing_module.dart';
import 'modules/notifications_module.dart';
import 'modules/platform_module.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  await registerExternalModule(sl);
  await registerPlatformModule(sl);
  await registerIdentityModule(sl);
  await registerCircleModule(sl);
  await registerPresenceModule(sl);
  await registerGeofencingModule(sl);
  await registerNotificationsModule(sl);
}
