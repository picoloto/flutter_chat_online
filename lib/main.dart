import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

void main() {
  runApp(MyApp());
}

final ThemeData kIOSTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.grey[100],
    primaryColorBrightness: Brightness.light);

final ThemeData kDefaultTheme = ThemeData(
    primarySwatch: Colors.purple, accentColor: Colors.orangeAccent[400]);

final googleSingIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

Future<Null> _ensureLoggedIn() async {
  GoogleSignInAccount user = googleSingIn.currentUser;
  if (user == null) user = await googleSingIn.signInSilently();

  if (user == null) user = await googleSingIn.signIn();

  if (await auth.currentUser() == null) {
    GoogleSignInAuthentication credentials =
        await googleSingIn.currentUser.authentication;
    await auth.signInWithGoogle(
        idToken: credentials.idToken, accessToken: credentials.accessToken);
  }
}

_handleSubmitted(String text) async {
  await _ensureLoggedIn();
  _sendMessage(text: text);
}

void _sendMessage({String text, String imgUrl}) {
  Firestore.instance.collection("mensagens").add({
    "text": text,
    "imgUrl": imgUrl,
    "senderName": googleSingIn.currentUser.displayName,
    "senderPhotoUrl": googleSingIn.currentUser.photoUrl
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Chat Teste",
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context).platform == TargetPlatform.iOS
          ? kIOSTheme
          : kDefaultTheme,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Chat Teste"),
          centerTitle: true,
          elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0 : 4,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
                child: StreamBuilder(
              stream: Firestore.instance.collection("mensagens").snapshots(),
              builder: (context, snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                  case ConnectionState.waiting:
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  default:
                    return ListView.builder(
                      reverse: true,
                      itemCount: snapshot.data.documents.length,
                      itemBuilder: (context, index) {
                        List r = snapshot.data.documents.reversed.toList();
                        return ChatMessage(r[index].data);
                      },
                    );
                }
              },
            )),
            Divider(
              height: 1,
            ),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: TextComposer(),
            )
          ],
        ),
      ),
    );
  }
}

class TextComposer extends StatefulWidget {
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  final _textController = TextEditingController();
  bool _isComposing = false;

  void _reset() {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).accentColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200])))
            : null,
        child: Row(
          children: <Widget>[
            Container(
              child: IconButton(
                icon: Icon(Icons.photo_camera),
                onPressed: () {
                  _showOptions(context);
                },
              ),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration:
                    InputDecoration.collapsed(hintText: "Enviar uma mensagem"),
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.length > 0;
                  });
                },
                onSubmitted: (text) {
                  _handleSubmitted(text);
                  _reset();
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoButton(
                      child: Text("Enviar"),
                      onPressed: _isComposing
                          ? () {
                              _handleSubmitted(_textController.text);
                              _reset();
                            }
                          : null,
                    )
                  : IconButton(
                      icon: Icon(Icons.send),
                      onPressed: _isComposing
                          ? () {
                              _handleSubmitted(_textController.text);
                              _reset();
                            }
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return BottomSheet(
            onClosing: () {},
            builder: (context) {
              return Container(
                padding: EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: FlatButton(
                        child: Text(
                          "Galeria",
                          style: TextStyle(fontSize: 20),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _ensureLoggedIn();
                          File imgFile = await ImagePicker.pickImage(
                              source: ImageSource.gallery);
                          if (imgFile == null) return;
                          StorageUploadTask task = FirebaseStorage.instance
                              .ref()
                              .child(googleSingIn.currentUser.id.toString() +
                                  DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString())
                              .putFile(imgFile);
                          task.onComplete.then((returnTask) {
                            returnTask.ref.getDownloadURL().then((url) {
                              _sendMessage(imgUrl: url);
                            });
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: FlatButton(
                        child: Text(
                          "Camera",
                          style: TextStyle(fontSize: 20),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _ensureLoggedIn();
                          File imgFile = await ImagePicker.pickImage(
                              source: ImageSource.camera);
                          if (imgFile == null) return;
                          StorageUploadTask task = FirebaseStorage.instance
                              .ref()
                              .child(googleSingIn.currentUser.id.toString() +
                                  DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString())
                              .putFile(imgFile);
                          task.onComplete.then((returnTask) {
                            returnTask.ref.getDownloadURL().then((url) {
                              _sendMessage(imgUrl: url);
                            });
                          });
                        },
                      ),
                    )
                  ],
                ),
              );
            },
          );
        });
  }
}

class ChatMessage extends StatelessWidget {
  final Map<String, dynamic> data;

  ChatMessage(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundImage: NetworkImage(data["senderPhotoUrl"] ??
                  'http://aux.iconspalace.com/uploads/19682701751567859374.png'),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(data['senderName'],
                    style: Theme.of(context).textTheme.subhead),
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  child: data['imgUrl'] != null
                      ? Image.network(
                          data['imgUrl'],
                          width: 250,
                        )
                      : Text(data['text']),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
