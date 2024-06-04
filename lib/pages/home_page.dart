import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:remotevision_controller/auth.dart';
import 'package:remotevision_controller/classes/signaling.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<HomePage> {
  final Auth auth = Auth();

  String? username;

  Signaling signaling = Signaling();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  TextEditingController textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _remoteRenderer.initialize();
    _findAndJoinRoom();
  }

  Future<void> _loadUsername() async {
    String? fetchedUsername = await auth.getUsername();
    setState(() {
      username = fetchedUsername;
    });
  }

  Widget _welcomeText() {
    return Text(
      'Welcome, $username!',
      style: const TextStyle(fontSize: 18),
    );
  }

  Future<void> _findAndJoinRoom() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    var rooms = await db.collection('rooms').get();

    if (rooms.docs.isNotEmpty) {
      String roomId = rooms.docs.first.id;
      await signaling.joinRoom(roomId, _remoteRenderer);

      Fluttertoast.showToast(
        msg: 'Joined room with ID: $roomId',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } else {
      Fluttertoast.showToast(
        msg: 'No available rooms to join',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Widget _reJoin() {
    return ElevatedButton(
      onPressed: _findAndJoinRoom,
      child: const Text("Re-join"),
    );
  }

  Widget _hangupButton() {
    return ElevatedButton(
      onPressed: () async {
        await signaling.hangUp();
      },
      child: const Text("Hangup"),
    );
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Widget _signOutButton() {
    return ElevatedButton(
      onPressed: signOut,
      child: const Text('Sign Out'),
    );
  }

  Widget _controlRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _reJoin(),
        _hangupButton(),
      ],
    );
  }

  @override
  void dispose() {
    signaling.hangUp();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("RemoteVison-Controller"),
            _signOutButton(),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          const SizedBox(height: 10.0),
          _welcomeText(),
          const SizedBox(height: 20.0),
          _controlRow(),
          const SizedBox(height: 20.0),
          Expanded(child: RTCVideoView(_remoteRenderer)),
          //const SizedBox(height: 30),
        ],
      ),
    );
  }
}
