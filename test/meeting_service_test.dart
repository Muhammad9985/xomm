import 'package:flutter_test/flutter_test.dart';
import 'package:xomm/models/meeting_model.dart';
import 'package:xomm/services/meeting_service.dart';

void main() {
  group('MeetingService Tests', () {
    test('generateMeetingCode produces valid formatted code', () {
      final code = MeetingService.generateMeetingCode();
      expect(code.startsWith('XOM-'), isTrue);
      expect(code.length, 11); // XOM-xxx-xxx
    });

    test('createMeeting with autoAccept=true allows immediate joining', () async {
      final service = MeetingService.instance;
      final meeting = await service.createMeeting(
        hostId: 'host_1',
        hostName: 'Alice Host',
        autoAccept: true,
      );

      expect(meeting.code.isNotEmpty, isTrue);
      expect(meeting.autoAccept, isTrue);

      final lookup = await service.getMeetingByCode(meeting.code);
      expect(lookup?.id, meeting.id);

      // Guest joins
      final status = await service.requestToJoin(
        meetingId: meeting.id,
        userId: 'guest_1',
        userName: 'Bob Guest',
      );

      // Should be immediately accepted because autoAccept is true
      expect(status, JoinRequestStatus.accepted);
    });

    test('createMeeting with autoAccept=false requires host admission', () async {
      final service = MeetingService.instance;
      final meeting = await service.createMeeting(
        hostId: 'host_2',
        hostName: 'Host Charlie',
        autoAccept: false,
      );

      expect(meeting.autoAccept, isFalse);

      // Guest requests to join
      final status = await service.requestToJoin(
        meetingId: meeting.id,
        userId: 'guest_2',
        userName: 'Dave Guest',
      );

      // Should be placed in pending status
      expect(status, JoinRequestStatus.pending);

      // Host receives waiting room notification and accepts
      await service.acceptParticipant(meeting.id, 'req_${meeting.id}_guest_2');
      // Verify via stream
      final participants = await service.watchParticipants(meeting.id).first;
      expect(participants.any((p) => p.id == 'host_2'), isTrue);
    });

    test('rejectParticipant marks request as rejected', () async {
      final service = MeetingService.instance;
      final meeting = await service.createMeeting(
        hostId: 'host_3',
        hostName: 'Host Eve',
        autoAccept: false,
      );

      await service.requestToJoin(
        meetingId: meeting.id,
        userId: 'guest_3',
        userName: 'Frank',
      );

      // Find request id
      final requests = await service.watchWaitingRoom(meeting.id).first;
      expect(requests.isNotEmpty, isTrue);
      final reqId = requests.first.id;

      // Host declines
      await service.rejectParticipant(meeting.id, reqId);

      // Waiting room now empty of pending requests
      final remaining = await service.watchWaitingRoom(meeting.id).first;
      expect(remaining.isEmpty, isTrue);
    });

    test('getMeetingByCode matches unicode en-dash and raw digits', () async {
      final service = MeetingService.instance;
      final meeting = await service.createMeeting(
        hostId: 'host_4',
        hostName: 'Unicode Host',
        autoAccept: true,
      );

      // Extract parts e.g. "XOM-767-822"
      final parts = meeting.code.split('-');
      final part1 = parts[1];
      final part2 = parts[2];

      // 1. Test with unicode en-dash (from keyboard auto-dash)
      final unicodeDashCode = 'XOM-$part1\u2013$part2';
      final lookup1 = await service.getMeetingByCode(unicodeDashCode);
      expect(lookup1?.id, meeting.id);

      // 2. Test with raw digits only
      final rawDigits = '$part1$part2';
      final lookup2 = await service.getMeetingByCode(rawDigits);
      expect(lookup2?.id, meeting.id);

      // 3. Test with lowercase and spaces
      final looseCode = 'xom $part1 $part2';
      final lookup3 = await service.getMeetingByCode(looseCode);
      expect(lookup3?.id, meeting.id);
    });

    test('endMeeting rejects unauthorized non-host and allows host', () async {
      final service = MeetingService.instance;
      final meeting = await service.createMeeting(
        hostId: 'real_host_123',
        hostName: 'Alice Host',
        autoAccept: true,
      );

      // 1. Non-host attempts to end meeting -> Rejected
      final nonHostResult = await service.endMeeting(
        meeting.id,
        requesterId: 'unauthorized_guest_999',
      );
      expect(nonHostResult, isFalse);

      final lookupActive = await service.getMeetingByCode(meeting.code);
      expect(lookupActive?.isEnded, isFalse);

      // 2. Real host ends meeting -> Accepted
      final hostResult = await service.endMeeting(
        meeting.id,
        requesterId: 'real_host_123',
      );
      expect(hostResult, isTrue);

      final lookupEnded = await service.getMeetingByCode(meeting.code);
      expect(lookupEnded, isNull); // getMeetingByCode filters isEnded == false
    });

    test('endMeeting marks meeting as ended and notifies watchMeeting stream', () async {
      final service = MeetingService.instance;
      final meeting = await service.createMeeting(
        hostId: 'host_end',
        hostName: 'End Host',
        autoAccept: true,
      );

      Meeting? latestMeeting;
      final sub = service.watchMeeting(meeting.id).listen((m) {
        latestMeeting = m;
      });

      await Future.delayed(const Duration(milliseconds: 10));
      expect(latestMeeting?.isEnded, isFalse);

      await service.endMeeting(meeting.id);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(latestMeeting?.isEnded, isTrue);
      await sub.cancel();
    });
  });
}
