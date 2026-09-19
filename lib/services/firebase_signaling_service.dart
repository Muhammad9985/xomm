/// Firebase Firestore WebRTC Signaling Adapter (100% Free on Firebase Spark Plan)
///
/// Firestore Data Structure for Xomm Meetings:
/// -------------------------------------------
/// - Collection `meetings`:
///   - Document `{meetingId}`:
///     - `code`: String (e.g. 'XOM-492-817')
///     - `title`: String
///     - `hostId`: String
///     - `hostName`: String
///     - `autoAccept`: Boolean (true: guests join immediately; false: wait for host)
///     - `createdAt`: Timestamp
///     - `isEnded`: Boolean
///
///   - Subcollection `requests` (`meetings/{meetingId}/requests/{requestId}`):
///     - `userId`: String
///     - `userName`: String
///     - `status`: String ('pending' | 'accepted' | 'rejected')
///     - `requestedAt`: Timestamp
///
///   - Subcollection `participants` (`meetings/{meetingId}/participants/{userId}`):
///     - `name`: String
///     - `isHost`: Boolean
///     - `isAudioMuted`: Boolean
///     - `isVideoMuted`: Boolean
///     - `joinedAt`: Timestamp
///
///   - Subcollection `signaling` (`meetings/{meetingId}/signaling/{peerId}`):
///     - `offer`: Map (SDP Offer)
///     - `answer`: Map (SDP Answer)
///     - `candidates`: Array of ICE candidates
///
/// Free Tier Quota on Spark Plan:
/// - 50,000 document reads / day (More than enough for hundreds of video calls daily)
/// - 20,000 document writes / day
/// - 1 GB storage
/// - Google STUN Server: `stun:stun.l.google.com:19302` (Free & Unlimited worldwide)
library;

import 'package:flutter/foundation.dart';

class FirebaseSignalingConfig {
  static const String googleStunServer = 'stun:stun.l.google.com:19302';
  
  static const Map<String, dynamic> rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  /// Recommended Firestore Security Rules for Spark Plan:
  /// ```
  /// rules_version = '2';
  /// service cloud.firestore {
  ///   match /databases/{database}/documents {
  ///     match /meetings/{meetingId} {
  ///       allow read, write: if true;
  ///       match /requests/{requestId} {
  ///         allow read, write: if true;
  ///       }
  ///       match /participants/{participantId} {
  ///         allow read, write: if true;
  ///       }
  ///       match /chat/{messageId} {
  ///         allow read, write: if true;
  ///       }
  ///       match /signaling/{peerId} {
  ///         allow read, write: if true;
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  static void printSetupGuide() {
    debugPrint('Xomm Firebase Free Signaling is active.');
  }
}
