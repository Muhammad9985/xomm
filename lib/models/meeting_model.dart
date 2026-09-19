enum JoinRequestStatus {
  pending,
  accepted,
  rejected,
}

class Meeting {
  final String id;
  final String code;
  final String title;
  final String hostId;
  final String hostName;
  final bool autoAccept;
  final DateTime createdAt;
  final bool isEnded;

  const Meeting({
    required this.id,
    required this.code,
    required this.title,
    required this.hostId,
    required this.hostName,
    required this.autoAccept,
    required this.createdAt,
    this.isEnded = false,
  });

  Meeting copyWith({
    String? id,
    String? code,
    String? title,
    String? hostId,
    String? hostName,
    bool? autoAccept,
    DateTime? createdAt,
    bool? isEnded,
  }) {
    return Meeting(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      autoAccept: autoAccept ?? this.autoAccept,
      createdAt: createdAt ?? this.createdAt,
      isEnded: isEnded ?? this.isEnded,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'hostId': hostId,
      'hostName': hostName,
      'autoAccept': autoAccept,
      'createdAt': createdAt.toIso8601String(),
      'isEnded': isEnded,
    };
  }

  factory Meeting.fromMap(Map<String, dynamic> map) {
    return Meeting(
      id: map['id'] as String,
      code: map['code'] as String,
      title: map['title'] as String? ?? 'Xomm Meeting',
      hostId: map['hostId'] as String,
      hostName: map['hostName'] as String? ?? 'Host',
      autoAccept: map['autoAccept'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      isEnded: map['isEnded'] as bool? ?? false,
    );
  }
}

class JoinRequest {
  final String id;
  final String meetingId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final JoinRequestStatus status;
  final DateTime requestedAt;

  const JoinRequest({
    required this.id,
    required this.meetingId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.status,
    required this.requestedAt,
  });

  JoinRequest copyWith({
    String? id,
    String? meetingId,
    String? userId,
    String? userName,
    String? userAvatar,
    JoinRequestStatus? status,
    DateTime? requestedAt,
  }) {
    return JoinRequest(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meetingId': meetingId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'status': status.name,
      'requestedAt': requestedAt.toIso8601String(),
    };
  }

  factory JoinRequest.fromMap(Map<String, dynamic> map) {
    return JoinRequest(
      id: map['id'] as String,
      meetingId: map['meetingId'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String? ?? 'Guest',
      userAvatar: map['userAvatar'] as String?,
      status: JoinRequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => JoinRequestStatus.pending,
      ),
      requestedAt: DateTime.tryParse(map['requestedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class Participant {
  final String id;
  final String name;
  final bool isHost;
  final bool isAudioMuted;
  final bool isVideoMuted;
  final bool isScreenSharing;
  final DateTime joinedAt;

  const Participant({
    required this.id,
    required this.name,
    this.isHost = false,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
    this.isScreenSharing = false,
    required this.joinedAt,
  });

  Participant copyWith({
    String? id,
    String? name,
    bool? isHost,
    bool? isAudioMuted,
    bool? isVideoMuted,
    bool? isScreenSharing,
    DateTime? joinedAt,
  }) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isHost': isHost,
      'isAudioMuted': isAudioMuted,
      'isVideoMuted': isVideoMuted,
      'isScreenSharing': isScreenSharing,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Participant',
      isHost: map['isHost'] as bool? ?? false,
      isAudioMuted: map['isAudioMuted'] as bool? ?? false,
      isVideoMuted: map['isVideoMuted'] as bool? ?? false,
      isScreenSharing: map['isScreenSharing'] as bool? ?? false,
      joinedAt: DateTime.tryParse(map['joinedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String? ?? 'Unknown',
      text: map['text'] as String,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
