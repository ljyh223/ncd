import 'dart:convert';
import 'dart:io';

import 'package:ncd/config/config.dart';
import 'package:ncd/model/PlayList.dart';
import 'package:ncd/src/api.dart';
import 'package:ncd/utils/Utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_taggy/flutter_taggy.dart';
import 'package:image/image.dart' as imglib;

import '../widget/InputDialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePage createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  late SharedPreferences prefs;
  late PlayListInfo playList;
  var flag = false;

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    // 在界面初始化时从SharedPreferences中读取开关的状态
    Taggy.initialize();
    initSharedPreferences();
    initNotification();
  }

  initSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  initNotification() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var android = const AndroidInitializationSettings('@mipmap/ic_launcher');
    var initSettings = InitializationSettings(android: android);
    flutterLocalNotificationsPlugin.initialize(initSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // 频道名称
      description: 'This channel is used for important notifications.', // 描述
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  showNotification(String title,String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your_channel_id', // 渠道ID
      'Channel Name', // 渠道名称
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // 使用show()方法发送通知，确保设置了foregroundNotificationId
    await flutterLocalNotificationsPlugin.show(
      0, // notification ID
      title, // 通知标题
      body, // 通知内容
      platformChannelSpecifics,
      payload: 'item x', // 可选的payload
    );
  }

  var logs = [];

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(10.0),
        child: Scaffold(
            body: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (BuildContext ctx, int index) {
                  var c = Colors.black;
                  if (logs[index]['type'] == 'wring') c = Colors.red;
                  if (logs[index]['type'] == 'success') c = Colors.green;

                  return Text(
                    logs[index]['msg'],
                    style: TextStyle(fontSize: 14, color: c),
                  );
                }),
            floatingActionButton: SpeedDial(children: [
              SpeedDialChild(
                  child: const Icon(Icons.play_arrow),
                  backgroundColor: Colors.green,
                  // get
                  labelStyle: const TextStyle(fontSize: 18.0),
                  onTap: () async {
                    Taggy.initialize();
                    String inputText = await showDialog(
                          context: context,
                          builder: (BuildContext context) => const InputDialog(
                              title: Text("give me your id"), hintText: "id"),
                        ) ??
                        "";
                    if (inputText == "") return;

                    // print(inputText);
                    playList = await API().getAllMusic(inputText);

                    flag = true;
                    var names = playList.musics.values
                        .map((e) => {'msg': e.name, 'type': ''})
                        .toList();
                    setState(() {
                      logs = names;
                    });

                    var path = prefs.getString("path") ?? defaultPath;
                    playList.path =
                        '$path${Utils.specialStrRe(playList.name)}/';
                    var file = File('$path${playList.id}.json');
                    if (!await file.exists()) {
                      file.create();
                    }
                  }),
              SpeedDialChild(
                child: const Icon(Icons.download),
                backgroundColor: Colors.blueAccent,
                labelStyle: const TextStyle(fontSize: 18.0),
                onTap: () async {
                  if (!flag) {
                    return;
                  }

                  await downloadMusic();
                },
              ),
              SpeedDialChild(
                  child: const Icon(Icons.star_rounded),
                  backgroundColor: Colors.red,
                  onTap: () async {
                    await showNotification("test","body");
                  })
            ], child: const Icon(Icons.add))));
  }

  addLog(String msg, String type) {
    setState(() {
      logs.add({'msg': msg, 'type': type});
    });
  }

  downloadMusic() async {
    var path = prefs.getString("path") ?? defaultPath;

    var dir = Directory(playList.path);
    if (!dir.existsSync()) {
      dir.createSync();
    }
    var file = File('$path${playList.id}.json');
    if (await file.exists()) {
      var fileData = file.readAsStringSync(encoding: utf8);
      if (fileData.isNotEmpty) {
        var jsonData = jsonDecode(fileData);
        // print("前 ==>${playList.musics.length}");
        for (var element in PlayListInfo.fromJson(jsonData).musics.keys) {
          //已经有的就移除
          // print("已经存在 ==> $element");
          playList.musics.remove(element);
        }
        // print("后 ==> ${playList.musics.length}");
      }
    }
    await API().getMusicUrl(playList);

    if (playList.musics.isEmpty) return addLog("没有需要下载的", "info");
    int successCount = 0;
    addLog('歌单--${playList.name}--开始下载, 总共${playList.musics.length}首', '');

    // 下载环节
    for (var e in playList.musics.values) {
      if (e.fileType == '') {
        addLog('${e.name} url 为空, 跳过', 'wring');
        continue;
      }
      var filePath = '${playList.path}${e.name}.${e.fileType}';
      if (File(filePath).existsSync()) {
        continue;
      }
      var response = await http.get(Uri.parse(e.url));
      File(filePath).writeAsBytesSync(response.bodyBytes);
      addLog('${e.name} 下载完成', 'success');
      successCount++;
    }

    //写入json 文件
    var fileData = file.readAsStringSync(encoding: utf8);
    var tempPLayList = playList.deepCopy();
    if (fileData.isNotEmpty) {
      var jsonData = jsonDecode(fileData);
      tempPLayList.musics.addAll(PlayListInfo.fromJson(jsonData).musics);
    }

    file.writeAsString(jsonEncode(tempPLayList));

    addLog(
        '歌单--${playList.name}--下载完成, 总共${playList.musics.length}首, 成功下载$successCount首',
        'success');
    addLog('-----------', '');

    //嵌入标签
    for (var e in playList.musics.values) {
      if (e.fileType == '') {
        addLog("${e.name} url 异常, 跳过", "wring");
        continue;
      }
      var filePath = '${playList.path}${e.name}.${e.fileType}';

      var result = await http.get(Uri.parse(e.picUrl), headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:126.0) Gecko/20100101 Firefox/126.0'
      });
      var picData = result.bodyBytes;
      //png
      if (picData[0] == 0x89 &&
          picData[1] == 0x50 &&
          picData[2] == 0x4E &&
          picData[3] == 0x47) {
        var img = imglib.decodeImage(picData);
        picData = imglib.encodeJpg(img!, quality: 80);
        print(e.picUrl);
      }
      print('${e.id}----------${e.name}');
      var tag = Tag(
          tagType: TagType.FilePrimaryType,
          pictures: [
            Picture(
                picType: PictureType.CoverFront,
                picData: picData,
                mimeType: MimeType.Jpeg)
          ],
          album: e.album,
          trackTitle: e.name,
          trackArtist: e.singer,
          lyrics: await API().getLyric(e.id));

      await Taggy.writePrimary(path: filePath, tag: tag, keepOthers: true);
      addLog('${e.name} 标签完成', 'success');
    }
    addLog('我滴任务完成啦!!!!', 'success');
  }
}
