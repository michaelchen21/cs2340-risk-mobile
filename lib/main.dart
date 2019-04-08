import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'packets.dart';
import 'dart:convert' as JSON;

enum Maybe { True, False, Idk }

// final channel = IOWebSocketChannel.connect('ws://localhost:9000/ws');
// To find the IP of your server, type ipconfig in Command Prompt and Wireless LAN adapter Wi-Fi: IPv4 address
final channel = IOWebSocketChannel.connect('ws://128.61.117.149:9000');
var token = "";
var publicToken = "";
var showSnackBar = false;
var yourName = "";
var nameIsValid = Maybe.Idk;
var nameAssignResult = Maybe.Idk;
var players = ["Mic", "Alice", "Bob", "Carol", "Dan", "Eve"];
List<Room> rooms = [Room("Room1", "mwahaha", ["hehe", "lol", "jk"]), Room("Room2", "ya", ["whoa", "uh huh"])];
var yourRoom;
var isReady = false;
const MIN_PLAYERS = 2; // minimum number of players to start a game, excluding the host
var subscription = channel.stream.listen((message) {
  print(message);
  Map<String, dynamic> msg = JSON.jsonDecode(message);
  switch (msg["_type"]) {
    case 'actors.Token':
      token = msg["token"];
      publicToken = msg["publicToken"];
      showSnackBar = true;
      break;
    case 'actors.Ping':
      var packet = {
        "_type": "Pong",
        "msg": "Pong"
      };
      channel.sink.add(JSON.jsonEncode(packet));
      break;
    case 'actors.NameCheckResult':
      if (msg["name"] == yourName)
        nameIsValid = (msg["available"] == 'true') ? Maybe.True : Maybe.False;
      break;
    case 'actors.NameAssignResult':
      if (msg["name"] == yourName)
        nameAssignResult = (msg["available"] == 'true') ? Maybe.True : Maybe.False;
      break;
    case 'actors.NotifyClientsChanged':
      players = [];
      for (var clientBrief in msg["clientSeq"]) {
        players.add(clientBrief["name"]);
      }
      break;
    case 'actors.CreatedRoom':
      break;
    case 'actors.RoomCreationResult':
      break;
    case 'actors.NotifyRoomsChanged':
      break;
    case 'actors.JoinedRoom':
      break;
    case 'actors.NotifyRoomStatus':
      break;
    case 'actors.NotifyGameStarted':
      break;
    case 'actors.NotifyGameState':
      break;
    case 'actors.SendMapResource':
      break;
    case 'actors.NotifyTurn':
      break;
    case 'actors.Err':
      break;
    default:
      print(message);
  }
});

void main() {
  runApp(new RiskApp());
}

class RiskApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "RISC!",
      theme: kDefaultTheme,
      home: HomePage()
    );
  }
}

final ThemeData kDefaultTheme = new ThemeData(
  primarySwatch: Colors.blue,
  accentColor: Colors.purpleAccent[400],
  brightness: Brightness.dark
);

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final snackBar = SnackBar(
    content: Text('Connected to server')
  );

  @override                               
  Widget build(BuildContext context) {
    if (showSnackBar) {
      Scaffold.of(context).showSnackBar(snackBar);
      showSnackBar = false;
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          children: <Widget>[
            SizedBox(height: 80.0),
            Column(
              children: <Widget>[
                // Image.asset('assets/login_icon.png'),
                SizedBox(height: 20.0),
                Text('RISC!')
              ]
            ),
            SizedBox(height: 120.0),
            TextField(
              decoration: InputDecoration(
                labelText: 'Enter Name'
              ),
              onChanged: (text) {
                nameIsValid = Maybe.Idk;
                yourName = text;
                checkName(yourName, token, channel);
                // Server response: NameCheckResult, according to which nameIsValid is updated
              },
              // See https://flutter.dev/docs/cookbook/forms/validation – we'd need to change this from a TextField to a TextFormField
              // validator: (value) {
              //   if (value.isEmpty) {
              //     return 'Please enter some text';
              //   } else if (nameIsValid == Maybe.False) {
              //     return 'That name is already taken';
              //   }
              // }
            ),
            SizedBox(height: 12.0), // spacer
            RaisedButton(
              child: Text('START'),
              onPressed: () {
                if (nameIsValid == Maybe.Idk || nameIsValid == Maybe.False) return null;
                setName(yourName, token, channel);
                // TODO: go to lobby page only after NameAssignResult validation?
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LobbyPage())
                );
              }
            )
          ]
        )
      )
    );
  }
}

class LobbyPage extends StatefulWidget {
  @override
  State createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: Drawer(
        child: ListView.builder(
          itemCount: players.length,
          itemBuilder: (context, index) {
            final item = players[index];
            if (item == yourName)
              return ListTile(
                title: Text(item),
                subtitle: Text("(me)")
              );
            else
              return ListTile(
                title: Text(item)
              );
          }
        )
      ),
      appBar: AppBar(
        title: Text('Rooms'),
        actions: <Widget>[
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.people),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: 'Players'
            )
          ),
          IconButton(
            icon: Icon(Icons.add),
            tooltip: 'Create Room',
            onPressed: () => _createRoomDialog(context)
          )
        ]
      ),
      body: ListView.builder(
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return ListTile(
            title: Text(room.roomName),
            subtitle: (room.otherPlayers.isEmpty) ? Text("👑" + room.host) : Text("👑" + room.host + ", " + room.otherPlayers.join(", ")),
            trailing: Opacity(
              opacity: yourRoom == null || yourRoom == room ? 1.0 : 0.0,
              child: FlatButton(
                child: yourRoom == null ? const Text('JOIN') : const Text('READY'),
                onPressed: () {
                  if (yourRoom == null) { // Button shows JOIN
                    yourRoom = room;
                    room.otherPlayers.add(yourName);
                  } else if (!isReady && room.otherPlayers.length >= MIN_PLAYERS) { // Button shows READY
                    // TODO: send stuff to server
                    isReady = true;
                  } else {
                    return null;
                  }
                }
              )
            )
          );
        }
      )
    );
  }
}

void _createRoomDialog(BuildContext context) {
  String newRoomName;
  final tec = TextEditingController();

  showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Create Room'),
        content: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                autofocus: true,
                controller: tec,
                decoration: InputDecoration(
                  hintText: 'Room name'
                )
              )
            )
          ],
        ),
        actions: <Widget>[
          FlatButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.pop(context);
              }),
          FlatButton(
              child: const Text('CREATE'),
              onPressed: () {
                rooms.add(Room(tec.text, yourName, <String>[]));
                Navigator.pop(context);
                // TODO: handle creating room
              })
        ]
      );
    }
  );
}

/* References
https://github.com/flutter/flutter/issues/19606
https://stackoverflow.com/questions/51957960/how-to-change-the-enddrawer-icon-in-flutter
https://flutter.dev/docs/cookbook/design/drawer
https://flutter.dev/docs/cookbook/lists/mixed-list
https://flutter.dev/docs/cookbook/forms/retrieve-input
https://flutter.dev/docs/cookbook/networking/web-sockets
https://www.didierboelens.com/2018/06/web-sockets---build-a-real-time-game/
https://medium.com/flutter-community/reactive-programming-streams-bloc-6f0d2bd2d248
*/