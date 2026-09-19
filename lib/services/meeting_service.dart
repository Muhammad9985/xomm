import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/meeting_model.dart';

class DeviceIdManager {
  static String get id => 'usr_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
  static String get newId => 'usr_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
}

class MeetingService {
  // Singleton instance
  static final MeetingService instance = MeetingService._internal();
  MeetingService._internal();

  // In-memory reactive data stores (fallback when Firebase is not yet initialized)
  final Map<String, Meeting> _meetings = {};
  final Map<String, List<JoinRequest>> _waitingRooms = {};
  final Map<String, List<Participant>> _participants = {};
  final Map<String, List<ChatMessage>> _chats = {};

  // Stream Controllers for local mode
  final _waitingRoomControllers = <String, StreamController<List<JoinRequest>>>{};
  final _joinStatusControllers = <String, StreamController<JoinRequestStatus>>{};
  final _participantsControllers = <String, StreamController<List<Participant>>>{};
  final _chatControllers = <String, StreamController<List<ChatMessage>>>{};
  final _meetingControllers = <String, StreamController<Meeting?>>{};

  bool get isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore? get _firestore {
    if (isFirebaseReady) {
      try {
        return FirebaseFirestore.instance;
      } catch (e) {
        debugPrint('Firestore instance error: $e');
      }
    }
    return null;
  }

  /// Generates a friendly unique meeting code like "XOM-492-817"
  static String generateMeetingCode() {
    final rand = Random();
    final part1 = rand.nextInt(900) + 100;
    final part2 = rand.nextInt(900) + 100;
    return 'XOM-$part1-$part2';
  }

  /// Format raw user input: strips spaces, normalizes all unicode dashes (en-dash, em-dash),
  /// and automatically prefixes "XOM-" if user only entered digits.
  static String formatCode(String input) {
    String cleaned = input
        .replaceAll('\u2013', '-') // unicode en-dash
        .replaceAll('\u2014', '-') // unicode em-dash
        .replaceAll('\u2212', '-') // minus sign
        .replaceAll('\u2010', '-') // hyphen
        .replaceAll('\u2011', '-') // non-breaking hyphen
        .replaceAll(' ', '')
        .trim()
        .toUpperCase();

    // If user entered only 6 digits e.g. "767822" or "767-822"
    final digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length == 6 && !cleaned.startsWith('XOM-')) {
      return 'XOM-${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 6)}';
    }

    return cleaned;
  }

  /// Create a new meeting (Host action)
  Future<Meeting> createMeeting({
    required String hostId,
    required String hostName,
    required bool autoAccept,
    String? title,
  }) async {
    final code = generateMeetingCode();
    final meetingId = 'meet_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    final meeting = Meeting(
      id: meetingId,
      code: code,
      title: title ?? '$hostName\'s Xomm Room',
      hostId: hostId,
      hostName: hostName,
      autoAccept: autoAccept,
      createdAt: DateTime.now(),
    );

    // Save locally
    _meetings[meetingId] = meeting;
    _waitingRooms[meetingId] = [];
    _participants[meetingId] = [
      Participant(
        id: hostId,
        name: hostName,
        isHost: true,
        joinedAt: DateTime.now(),
      )
    ];
    _chats[meetingId] = [];

    _notifyParticipants(meetingId);
    _notifyWaitingRoom(meetingId);

    // Sync to Cloud Firestore if Firebase is connected
    final db = _firestore;
    if (db != null) {
      try {
        await db.collection('meetings').doc(meetingId).set(meeting.toMap());
        await db
            .collection('meetings')
            .doc(meetingId)
            .collection('participants')
            .doc(hostId)
            .set(Participant(
              id: hostId,
              name: hostName,
              isHost: true,
              joinedAt: DateTime.now(),
            ).toMap());
      } catch (e) {
        debugPrint('Firestore save meeting error: $e');
      }
    }

    return meeting;
  }

  /// Find meeting by code (supports full code, unicode dashes, and raw digits)
  Future<Meeting?> getMeetingByCode(String code) async {
    final cleaned = formatCode(code);
    final rawDigits = code.replaceAll(RegExp(r'[^0-9]'), '');

    // Check Cloud Firestore first if available
    final db = _firestore;
    if (db != null) {
      try {
        // 1. Direct query by formatted code
        final query = await db
            .collection('meetings')
            .where('code', isEqualTo: cleaned)
            .where('isEnded', isEqualTo: false)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          final m = Meeting.fromMap(doc.data());
          _meetings[m.id] = m;
          return m;
        }

        // 2. Query by un-prefixed format or digits
        if (rawDigits.length >= 4) {
          final recentMeetings = await db
              .collection('meetings')
              .where('isEnded', isEqualTo: false)
              .limit(50)
              .get();

          for (final doc in recentMeetings.docs) {
            final m = Meeting.fromMap(doc.data());
            final mDigits = m.code.replaceAll(RegExp(r'[^0-9]'), '');
            if (mDigits == rawDigits || formatCode(m.code) == cleaned) {
              _meetings[m.id] = m;
              return m;
            }
          }
        }
      } catch (e) {
        debugPrint('Firestore query by code error: $e');
      }
    }

    // Fallback to local memory (also matches by digits and normalized code)
    for (final meeting in _meetings.values) {
      final mDigits = meeting.code.replaceAll(RegExp(r'[^0-9]'), '');
      if ((formatCode(meeting.code) == cleaned || (rawDigits.isNotEmpty && mDigits == rawDigits)) &&
          !meeting.isEnded) {
        return meeting;
      }
    }
    return null;
  }

  /// Find meeting by ID
  Future<Meeting?> getMeetingById(String meetingId) async {
    final db = _firestore;
    if (db != null) {
      try {
        final doc = await db.collection('meetings').doc(meetingId).get();
        if (doc.exists && doc.data() != null) {
          return Meeting.fromMap(doc.data()!);
        }
      } catch (e) {
        debugPrint('Firestore get meeting error: $e');
      }
    }
    return _meetings[meetingId];
  }

  /// Request to join a meeting (Guest action)
  Future<JoinRequestStatus> requestToJoin({
    required String meetingId,
    required String userId,
    required String userName,
    String? userAvatar,
  }) async {
    final meeting = await getMeetingById(meetingId);
    if (meeting == null || meeting.isEnded) {
      throw Exception('Meeting not found or has ended.');
    }

    final db = _firestore;

    // If auto-accept is enabled by host:
    if (meeting.autoAccept) {
      _addParticipant(meetingId, userId, userName);
      if (db != null) {
        try {
          // Remove any stale participant document for this specific userId
          final existing = await db
              .collection('meetings')
              .doc(meetingId)
              .collection('participants')
              .get();
          for (final doc in existing.docs) {
            if (doc.id == userId) {
              await doc.reference.delete();
            }
          }

          await db
              .collection('meetings')
              .doc(meetingId)
              .collection('participants')
              .doc(userId)
              .set(Participant(
                id: userId,
                name: userName,
                joinedAt: DateTime.now(),
              ).toMap());
        } catch (e) {
          debugPrint('Firestore add participant error: $e');
        }
      }
      return JoinRequestStatus.accepted;
    }

    // Otherwise, place guest in Waiting Room
    final requestId = 'req_${DateTime.now().millisecondsSinceEpoch}_$userId';
    final request = JoinRequest(
      id: requestId,
      meetingId: meetingId,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      status: JoinRequestStatus.pending,
      requestedAt: DateTime.now(),
    );

    _waitingRooms.putIfAbsent(meetingId, () => []);
    _waitingRooms[meetingId]!.removeWhere((r) => r.userId == userId);
    _waitingRooms[meetingId]!.add(request);

    _notifyWaitingRoom(meetingId);
    _notifyJoinStatus(meetingId, userId, JoinRequestStatus.pending);

    if (db != null) {
      try {
        await db
            .collection('meetings')
            .doc(meetingId)
            .collection('requests')
            .doc(requestId)
            .set(request.toMap());
      } catch (e) {
        debugPrint('Firestore submit join request error: $e');
      }
    }

    return JoinRequestStatus.pending;
  }

  /// Host admits a guest into the meeting
  Future<void> acceptParticipant(String meetingId, String requestId) async {
    final requests = _waitingRooms[meetingId];
    if (requests != null) {
      final index = requests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        final req = requests[index];
        requests[index] = req.copyWith(status: JoinRequestStatus.accepted);
        _addParticipant(meetingId, req.userId, req.userName);
        _notifyWaitingRoom(meetingId);
        _notifyJoinStatus(meetingId, req.userId, JoinRequestStatus.accepted);
      }
    }

    final db = _firestore;
    if (db != null) {
      try {
        await db
            .collection('meetings')
            .doc(meetingId)
            .collection('requests')
            .doc(requestId)
            .update({'status': JoinRequestStatus.accepted.name});

        final reqDoc = await db
            .collection('meetings')
            .doc(meetingId)
            .collection('requests')
            .doc(requestId)
            .get();

        if (reqDoc.exists && reqDoc.data() != null) {
          final req = JoinRequest.fromMap(reqDoc.data()!);

          // Delete existing stale participant with the same userId
          final existing = await db
              .collection('meetings')
              .doc(meetingId)
              .collection('participants')
              .get();
          for (final doc in existing.docs) {
            if (doc.id == req.userId) {
              await doc.reference.delete();
            }
          }

          await db
              .collection('meetings')
              .doc(meetingId)
              .collection('participants')
              .doc(req.userId)
              .set(Participant(
                id: req.userId,
                name: req.userName,
                joinedAt: DateTime.now(),
              ).toMap());
        }
      } catch (e) {
        debugPrint('Firestore accept participant error: $e');
      }
    }
  }

  /// Host admits all waiting participants at once
  Future<void> acceptAll(String meetingId) async {
    final requests = _waitingRooms[meetingId];
    if (requests != null) {
      for (final req in List<JoinRequest>.from(requests)) {
        if (req.status == JoinRequestStatus.pending) {
          await acceptParticipant(meetingId, req.id);
        }
      }
    }
  }

  /// Host declines a guest
  Future<void> rejectParticipant(String meetingId, String requestId) async {
    final requests = _waitingRooms[meetingId];
    if (requests != null) {
      final index = requests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        final req = requests[index];
        requests[index] = req.copyWith(status: JoinRequestStatus.rejected);
        _notifyWaitingRoom(meetingId);
        _notifyJoinStatus(meetingId, req.userId, JoinRequestStatus.rejected);
      }
    }

    final db = _firestore;
    if (db != null) {
      try {
        await db
            .collection('meetings')
            .doc(meetingId)
            .collection('requests')
            .doc(requestId)
            .update({'status': JoinRequestStatus.rejected.name});
      } catch (e) {
        debugPrint('Firestore reject error: $e');
      }
    }
  }

  /// Add participant to meeting
  void _addParticipant(String meetingId, String userId, String userName) {
    _participants.putIfAbsent(meetingId, () => []);
    _participants[meetingId]!.removeWhere((p) => p.id == userId);
    final meeting = _meetings[meetingId];
    final isHost = meeting != null && meeting.hostId.isNotEmpty && meeting.hostId == userId;
    _participants[meetingId]!.add(
      Participant(
        id: userId,
        name: userName,
        isHost: isHost,
        joinedAt: DateTime.now(),
      ),
    );
    _notifyParticipants(meetingId);
  }

  /// Participant leaves meeting
  Future<void> leaveMeeting(String meetingId, String userId) async {
    if (_participants[meetingId] != null) {
      _participants[meetingId]!.removeWhere((p) => p.id == userId);
      _notifyParticipants(meetingId);
    }
    if (_waitingRooms[meetingId] != null) {
      _waitingRooms[meetingId]!.removeWhere((r) => r.userId == userId);
      _notifyWaitingRoom(meetingId);
    }

    final db = _firestore;
    if (db != null) {
      try {
        await db
            .collection('meetings')
            .doc(meetingId)
            .collection('participants')
            .doc(userId)
            .delete();
      } catch (e) {
        debugPrint('Firestore leave meeting error: $e');
      }
    }
  }

  /// Update participant audio/video/screenshare status in Firestore
  Future<void> updateParticipantMedia({
    required String meetingId,
    required String userId,
    bool? isAudioMuted,
    bool? isVideoMuted,
    bool? isScreenSharing,
  }) async {
    final updates = <String, dynamic>{};
    if (isAudioMuted != null) updates['isAudioMuted'] = isAudioMuted;
    if (isVideoMuted != null) updates['isVideoMuted'] = isVideoMuted;
    if (isScreenSharing != null) updates['isScreenSharing'] = isScreenSharing;

    if (updates.isEmpty) return;

    // Update in memory
    final list = _participants[meetingId];
    if (list != null) {
      final index = list.indexWhere((p) => p.id == userId);
      if (index != -1) {
        list[index] = list[index].copyWith(
          isAudioMuted: isAudioMuted,
          isVideoMuted: isVideoMuted,
          isScreenSharing: isScreenSharing,
        );
        _notifyParticipants(meetingId);
      }
    }

    final db = _firestore;
    if (db != null) {
      try {
        await db
            .collection('meetings')
            .doc(meetingId)
            .collection('participants')
            .doc(userId)
            .update(updates);
      } catch (e) {
        debugPrint('Firestore update media error: $e');
      }
    }
  }

  /// End meeting for everyone (Host ONLY action)
  Future<bool> endMeeting(String meetingId, {String? requesterId}) async {
    final meeting = _meetings[meetingId];
    if (requesterId != null && meeting != null) {
      if (meeting.hostId.isNotEmpty && meeting.hostId != requesterId) {
        debugPrint('Unauthorized endMeeting attempt by non-host: $requesterId (host is ${meeting.hostId})');
        return false;
      }
    }

    final db = _firestore;
    if (db != null) {
      try {
        if (requesterId != null) {
          final doc = await db.collection('meetings').doc(meetingId).get();
          if (doc.exists) {
            final hostId = doc.data()?['hostId'];
            if (hostId != null && hostId.toString().isNotEmpty && hostId != requesterId) {
              debugPrint('Firestore unauthorized endMeeting attempt by non-host: $requesterId (host is $hostId)');
              return false;
            }
          }
        }

        await db.collection('meetings').doc(meetingId).update({
          'isEnded': true,
          'endedAt': FieldValue.serverTimestamp(),
        });

        // Clean up Firestore participants so none linger
        final partsSnap = await db
            .collection('meetings')
            .doc(meetingId)
            .collection('participants')
            .get();
        for (var doc in partsSnap.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Firestore end meeting error: $e');
      }
    }

    if (meeting != null) {
      _meetings[meetingId] = meeting.copyWith(isEnded: true);
    }
    _participants[meetingId]?.clear();
    _waitingRooms[meetingId]?.clear();
    _notifyMeeting(meetingId);
    _notifyParticipants(meetingId);
    _notifyWaitingRoom(meetingId);
    return true;
  }

  /// Send chat message
  Future<void> sendMessage(String meetingId, String senderId, String senderName, String text) async {
    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      text: text,
      timestamp: DateTime.now(),
    );

    _chats.putIfAbsent(meetingId, () => []);
    _chats[meetingId]!.add(msg);
    _notifyChat(meetingId);

    final db = _firestore;
    if (db != null) {
      try {
        await db
            .collection('meetings')
            .doc(meetingId)
            .collection('chat')
            .doc(msg.id)
            .set(msg.toMap());
      } catch (e) {
        debugPrint('Firestore chat error: $e');
      }
    }
  }

  // --- STREAM PROVIDERS ---

  /// Stream of waiting room requests (for Host)
  Stream<List<JoinRequest>> watchWaitingRoom(String meetingId) {
    final db = _firestore;
    if (db != null) {
      return db
          .collection('meetings')
          .doc(meetingId)
          .collection('requests')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => JoinRequest.fromMap(doc.data())).toList());
    }

    _waitingRoomControllers.putIfAbsent(
      meetingId,
      () => StreamController<List<JoinRequest>>.broadcast(),
    );
    Future.microtask(() {
      final current = (_waitingRooms[meetingId] ?? [])
          .where((r) => r.status == JoinRequestStatus.pending)
          .toList();
      _waitingRoomControllers[meetingId]?.add(current);
    });
    return _waitingRoomControllers[meetingId]!.stream;
  }

  /// Stream of user's join status (for Guest waiting in waiting room)
  Stream<JoinRequestStatus> watchJoinStatus(String meetingId, String userId) {
    final db = _firestore;
    if (db != null) {
      return db
          .collection('meetings')
          .doc(meetingId)
          .collection('requests')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isEmpty) return JoinRequestStatus.pending;
        final data = snapshot.docs.first.data();
        final statusStr = data['status'] as String?;
        return JoinRequestStatus.values.firstWhere(
          (e) => e.name == statusStr,
          orElse: () => JoinRequestStatus.pending,
        );
      });
    }

    final key = '${meetingId}_$userId';
    _joinStatusControllers.putIfAbsent(
      key,
      () => StreamController<JoinRequestStatus>.broadcast(),
    );
    return _joinStatusControllers[key]!.stream;
  }

  /// Stream of participants in the meeting
  Stream<List<Participant>> watchParticipants(String meetingId) {
    final db = _firestore;
    if (db != null) {
      return db
          .collection('meetings')
          .doc(meetingId)
          .collection('participants')
          .snapshots()
          .map((snapshot) {
        final seen = <String>{};
        final list = <Participant>[];
        for (final doc in snapshot.docs) {
          final p = Participant.fromMap(doc.data());
          if (!seen.contains(p.id)) {
            seen.add(p.id);
            list.add(p);
          }
        }
        return list;
      });
    }

    _participantsControllers.putIfAbsent(
      meetingId,
      () => StreamController<List<Participant>>.broadcast(),
    );
    Future.microtask(() {
      final current = _participants[meetingId] ?? [];
      _participantsControllers[meetingId]?.add(current);
    });
    return _participantsControllers[meetingId]!.stream;
  }

  /// Stream of chat messages
  Stream<List<ChatMessage>> watchChat(String meetingId) {
    final db = _firestore;
    if (db != null) {
      return db
          .collection('meetings')
          .doc(meetingId)
          .collection('chat')
          .orderBy('timestamp')
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList());
    }

    _chatControllers.putIfAbsent(
      meetingId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    Future.microtask(() {
      final current = _chats[meetingId] ?? [];
      _chatControllers[meetingId]?.add(current);
    });
    return _chatControllers[meetingId]!.stream;
  }

  void _notifyWaitingRoom(String meetingId) {
    final current = (_waitingRooms[meetingId] ?? [])
        .where((r) => r.status == JoinRequestStatus.pending)
        .toList();
    _waitingRoomControllers[meetingId]?.add(current);
  }

  void _notifyJoinStatus(String meetingId, String userId, JoinRequestStatus status) {
    final key = '${meetingId}_$userId';
    _joinStatusControllers[key]?.add(status);
  }

  void _notifyParticipants(String meetingId) {
    final current = _participants[meetingId] ?? [];
    _participantsControllers[meetingId]?.add(current);
  }

  void _notifyChat(String meetingId) {
    final current = _chats[meetingId] ?? [];
    _chatControllers[meetingId]?.add(current);
  }

  void _notifyMeeting(String meetingId) {
    final current = _meetings[meetingId];
    _meetingControllers[meetingId]?.add(current);
  }

  /// Stream of meeting status updates (including isEnded)
  Stream<Meeting?> watchMeeting(String meetingId) {
    final db = _firestore;
    if (db != null) {
      return db.collection('meetings').doc(meetingId).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        final meeting = Meeting.fromMap(snapshot.data()!);
        _meetings[meetingId] = meeting;
        return meeting;
      });
    }

    _meetingControllers.putIfAbsent(
      meetingId,
      () => StreamController<Meeting?>.broadcast(),
    );
    Future.microtask(() {
      _meetingControllers[meetingId]?.add(_meetings[meetingId]);
    });
    return _meetingControllers[meetingId]!.stream;
  }
}
