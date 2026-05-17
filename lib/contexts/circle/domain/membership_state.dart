sealed class MembershipState {
  const MembershipState();
}

final class UserNoCircle extends MembershipState {
  const UserNoCircle();
}

final class UserPendingRequest extends MembershipState {
  final String circleId;
  const UserPendingRequest({required this.circleId});
}

final class UserInCircle extends MembershipState {
  final String circleId;
  final bool isCreator;
  const UserInCircle({required this.circleId, required this.isCreator});
}
