class RoomMeta {
  final String id;
  final String callRequestId;
  final String hmsRoomId;
  final String hmsRoleMember;
  final String hmsRoleTrainer;

  const RoomMeta({
    required this.id,
    required this.callRequestId,
    required this.hmsRoomId,
    required this.hmsRoleMember,
    required this.hmsRoleTrainer,
  });
}
