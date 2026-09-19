import 'package:flutter_test/flutter_test.dart';
import 'package:xomm/services/signaling_manager.dart';

void main() {
  test('SDP Audio Optimizer injects and tunes Opus voice parameters', () {
    const rawSdp = '''
v=0
o=- 123456 2 IN IP4 127.0.0.1
s=-
t=0 0
m=audio 9 UDP/TLS/RTP/SAVPF 111 126
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=rtpmap:111 opus/48000/2
a=fmtp:111 minptime=10;useinbandfec=1
a=rtcp-fb:111 transport-cc
m=video 9 UDP/TLS/RTP/SAVPF 96
c=IN IP4 0.0.0.0
a=rtpmap:96 VP8/90000
''';

    final optimized = SignalingManager.optimizeAudioSdp(rawSdp);
    expect(optimized, contains('a=fmtp:111'));
    expect(optimized, contains('useinbandfec=1'));
    expect(optimized, contains('usedtx=1'));
    expect(optimized, contains('stereo=0'));
    expect(optimized, contains('sprop-stereo=0'));
    expect(optimized, contains('maxaveragebitrate=32000'));
    expect(optimized, contains('cbr=0'));
  });

  test('SDP Audio Optimizer creates fmtp line when missing', () {
    const rawSdpNoFmtp = '''
v=0
o=- 123456 2 IN IP4 127.0.0.1
s=-
t=0 0
m=audio 9 UDP/TLS/RTP/SAVPF 111
a=rtpmap:111 opus/48000/2
m=video 9 UDP/TLS/RTP/SAVPF 96
''';

    final optimized = SignalingManager.optimizeAudioSdp(rawSdpNoFmtp);
    expect(optimized, contains('a=fmtp:111 minptime=10;ptime=20;useinbandfec=1;usedtx=1;stereo=0;sprop-stereo=0;maxaveragebitrate=32000;cbr=0'));
  });
}
