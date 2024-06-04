import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class Signaling {
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  RTCDataChannel? dataChannel;
  String? roomId;

  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302'
        ]
      }
    ]
  };

  Future<void> openUserMedia(
      RTCVideoRenderer localRenderer, RTCVideoRenderer remoteRenderer) async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    var stream = await navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': true});
    localRenderer.srcObject = stream;
    localStream = stream;
  }

  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteRenderer) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('rooms').doc(roomId);
    var roomSnapshot = await roomRef.get();

    if (roomSnapshot.exists) {
      peerConnection = await createPeerConnection(configuration);
      registerPeerConnectionListeners();

      localStream?.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });

      peerConnection?.onTrack = (RTCTrackEvent event) {
        remoteRenderer.srcObject = event.streams[0];
        remoteStream = event.streams[0];
      };

      var data = roomSnapshot.data() as Map<String, dynamic>;
      var offer = data['offer'];
      await peerConnection?.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
      var answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(answer);

      Map<String, dynamic> roomWithAnswer = {
        'answer': {'type': answer.type, 'sdp': answer.sdp}
      };

      await roomRef.update(roomWithAnswer);

      roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
        for (var document in snapshot.docChanges) {
          if (document.type == DocumentChangeType.added) {
            var data = document.doc.data() as Map<String, dynamic>;
            peerConnection!.addCandidate(
              RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex'],
              ),
            );
          }
        }
      });

      // Initialize and set up the data channel for text streaming
      dataChannel = await peerConnection?.createDataChannel(
          "textChannel", RTCDataChannelInit());
      dataChannel?.onDataChannelState = (state) {
        print("Data channel state: $state");
      };
    }
  }

  void sendText(String text) {
    if (dataChannel != null) {
      dataChannel?.send(RTCDataChannelMessage(text));
    }
  }

  Future<void> hangUp() async {
    if (peerConnection != null) {
      await peerConnection!.close();
      peerConnection = null;
    }
    localStream?.getTracks().forEach((track) => track.stop());
    remoteStream?.getTracks().forEach((track) => track.stop());
    localStream?.dispose();
    remoteStream?.dispose();

    if (roomId != null) {
      await _deleteRoom(roomId!);
    }
  }

  Future<void> _deleteRoom(String roomId) async {
    var db = FirebaseFirestore.instance;
    var roomRef = db.collection('rooms').doc(roomId);

    var calleeCandidates = await roomRef.collection('calleeCandidates').get();
    for (var document in calleeCandidates.docs) {
      await document.reference.delete();
    }

    var callerCandidates = await roomRef.collection('callerCandidates').get();
    for (var document in callerCandidates.docs) {
      await document.reference.delete();
    }

    await roomRef.delete();
  }

  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state changed: $state');
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state change: $state');
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      print('Signaling state change: $state');
    };

    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE connection state change: $state');
    };

    peerConnection?.onAddStream = (MediaStream stream) {
      remoteStream = stream;
    };
  }
}
