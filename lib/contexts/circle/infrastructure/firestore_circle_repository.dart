import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/contexts/circle/application/ports/circle_repository.dart';
import 'package:nunakin_app/contexts/circle/domain/circle_entity.dart';
import 'package:nunakin_app/contexts/circle/domain/membership_state.dart';
import 'package:nunakin_app/services/circle_service.dart' as legacy;

class FirestoreCircleRepository implements CircleRepository {
  final legacy.CircleService _service;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreCircleRepository(this._service, this._firestore, this._auth);

  @override
  Stream<MembershipState> get membership =>
      _service.getUserCircleStream().map(_mapState);

  MembershipState _mapState(legacy.UserCircleState state) {
    final currentUid = _auth.currentUser?.uid ?? '';
    return switch (state) {
      legacy.UserInCircle(:final circle) => UserInCircle(
          circleId: circle.id,
          isCreator: circle.creatorId == currentUid,
        ),
      legacy.UserPendingRequest(:final pendingCircleId) =>
        UserPendingRequest(circleId: pendingCircleId),
      legacy.UserNoCircle() => const UserNoCircle(),
    };
  }

  @override
  Future<CircleEntity?> getCircle(String circleId) async {
    assert(circleId.isNotEmpty, 'circleId must not be empty');
    try {
      final doc = await _firestore.collection('circles').doc(circleId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return CircleEntity(
        id: doc.id,
        name: data['name'] as String? ?? '',
        invitationCode: data['invitation_code'] as String? ?? '',
        memberIds: List<String>.from(data['members'] as List? ?? []),
        creatorId: data['creatorId'] as String? ?? '',
      );
    } catch (e) {
      log('[CircleRepository] getCircle error: $e');
      return null;
    }
  }

  @override
  Future<String> createCircle(String name) {
    assert(name.isNotEmpty, 'circle name must not be empty');
    return _service.createCircle(name);
  }
}
