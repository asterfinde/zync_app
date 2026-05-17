class CircleEntity {
  final String id;
  final String name;
  final String invitationCode;
  final List<String> memberIds;
  final String creatorId;

  const CircleEntity({
    required this.id,
    required this.name,
    required this.invitationCode,
    required this.memberIds,
    required this.creatorId,
  });
}
