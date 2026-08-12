class RoomMetaEntity {
  final String id;
  final String callRequestId;
  final String hmsRoomId;
  final String hmsRoleMember;
  final String hmsRoleTrainer;

  const RoomMetaEntity({
    required this.id,
    required this.callRequestId,
    required this.hmsRoomId,
    required this.hmsRoleMember,
    required this.hmsRoleTrainer,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'callRequestId': callRequestId,
        'hmsRoomId': hmsRoomId,
        'hmsRoleMember': hmsRoleMember,
        'hmsRoleTrainer': hmsRoleTrainer,
      };

  factory RoomMetaEntity.fromJson(Map<String, dynamic> json) => RoomMetaEntity(
        id: json['id'] as String,
        callRequestId: json['callRequestId'] as String,
        hmsRoomId: json['hmsRoomId'] as String,
        hmsRoleMember: json['hmsRoleMember'] as String,
        hmsRoleTrainer: json['hmsRoleTrainer'] as String,
      );
}
