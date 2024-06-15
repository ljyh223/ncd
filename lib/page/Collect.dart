import 'dart:convert';
import 'dart:io';

import 'package:ncd/model/Music.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_taggy/flutter_taggy.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:ncd/model/LocalPlayList.dart';
import 'package:ncd/model/PlayList.dart';
import 'package:ncd/src/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as imglib;
import 'package:path/path.dart' as p;
import '../config/config.dart';
import '../utils/Utils.dart';

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  _CollectPage createState() => _CollectPage();
}

class _CollectPage extends State<CollectPage> {
  late SharedPreferences prefs;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  _loadPrefs() async {
    Taggy.initialize();
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

  showNotification(String title, String body) async {
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(10.0),
        child: Scaffold(
            body: Center(
                child: FutureBuilder(
          future: getLocalPlayList(),
          builder: (BuildContext context,
              AsyncSnapshot<List<LocalPlayList>> snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                // 请求失败，显示错误
                return Text("Error: ${snapshot.error}");
              } else {
                //完成
                var items = snapshot.data;
                if (items!.isEmpty) {
                  return const Text("没找到啊~");
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    var item = items[index];
                    return GestureDetector(
                      onTap: () async {
                        var result =
                            await Utils.alertDialog(context, "更新歌单", "是否更新歌单");
                        if (result != "T") {
                          return;
                        }
                        var playList = await API().getAllMusic(item.id);
                        var path = prefs.getString("path") ?? defaultPath;

                        var dir = Directory(playList.path);
                        if (!dir.existsSync()) {
                          dir.createSync();
                        }
                        var file = File('$path${playList.id}.json');

                        if (!await file.exists()) {
                          return;
                        }
                        var fileData = file.readAsStringSync(encoding: utf8);
                        if (fileData.isEmpty) {
                          return;
                        }

                        var jsonData = jsonDecode(fileData);
                        var localPlayList = PlayListInfo.fromJson(jsonData);
                        print("localPlayList ==> ${localPlayList.musics.length}");
                        print("playList ==> ${playList.musics.length}");
                        var temp = playList.musics.values
                            .where((m) => !localPlayList.musics.values.any(
                                (e) =>
                                    m.name ==
                                    e.name))
                            .toList();



                        result=await Utils.alertDialog(context, "是否继续", "预计更新${temp.length}首歌曲");

                        if(result!="T"){
                          Fluttertoast.showToast(
                              msg: '好滴',
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 1,
                              backgroundColor: Colors.green,
                              textColor: Colors.white,
                              fontSize: 16.0);
                          return;
                        }

                        if (temp.isEmpty) {
                          check(playList);
                          Fluttertoast.showToast(
                              msg: '没什么要更新的啊',
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 1,
                              backgroundColor: Colors.green,
                              textColor: Colors.white,
                              fontSize: 16.0);
                          return;
                        }
                        var subMusic = PlayListInfo(
                            name: playList.name,
                            id: playList.id,
                            path: playList.path,
                            picUrl: playList.picUrl,
                            musics: {});
                        for (var e in temp) {
                          subMusic.musics[e.id] = e;
                        }
                        // 下载环节
                        await API().getMusicUrl(subMusic);

                        await download(subMusic);

                        //写入json 文件

                        file.writeAsString(jsonEncode(playList));

                        //嵌入标签
                        await writeTag(subMusic);
                        await showNotification(
                            "下载完成", '共计下载: ${subMusic.musics.length}');
                        check(subMusic);
                      },
                      onLongPress: () async {
                        var result = await Utils.alertDialog(
                            context, "更新歌曲封面", "是否补全歌曲封面");

                        if (result != "T") {
                          return;
                        }

                        var path = prefs.getString("path") ?? defaultPath;
                        var file = File('$path${item.id}.json');
                        var fileData = file.readAsStringSync(encoding: utf8);
                        if (fileData.isNotEmpty) {
                          var jsonData = jsonDecode(fileData);
                          PlayListInfo playList =
                              PlayListInfo.fromJson(jsonData);

                          await check(playList);
                          await writeTag(playList);
                          await showNotification(
                              "嵌入标签完成",
                              '共计完成: '
                                  '${playList.musics.length}');
                        } else {
                          print("file data is empty");
                        }
                      },
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(item.subheading),
                        leading: FutureBuilder(
                          future: Utils.getImage(item.picUrl),
                          builder: (BuildContext context,
                              AsyncSnapshot<dynamic> snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              return Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadiusDirectional.circular(10)),
                                clipBehavior: Clip.antiAlias,
                                child: Image.memory(
                                  snapshot.data,
                                  fit: BoxFit.cover,
                                ),
                              );
                            } else {
                              return const Icon(Icons.file_download);
                            }
                          },
                        ),
                        trailing: const Icon(
                          Icons.check,
                          color: Colors.green,
                        ),
                      ),
                    );
                  },
                );
              }
            } else {
              return const CircularProgressIndicator();
            }
          },
        ))),
      ),
    );
  }

  writeTag(PlayListInfo playList) async {
    var count = 0;
    for ( var e in playList.musics.values) {

        if (e.fileType == '') {
          print("url 异常 ${e.name} -- ${e.id}");
          continue;
        };
        var filePath = '${playList.path}${e.name}.${e.fileType}';
        var result = await http.get(Uri.parse(e.picUrl), headers: {
          'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:126.0) Gecko/20100101 Firefox/126.0'
        });
        var picData = result.bodyBytes;
        if (picData[0] == 0x89 && picData[3] == 0x47) {
          var img = imglib.decodeImage(picData);
          picData = imglib.encodeJpg(img!, quality: 80);
          print('png to jpg ==> ${e.picUrl}');
        }



        try{
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
              lyrics: await API().getLyric(e.id)
          );
          await Taggy.writePrimary(path: filePath, tag: tag, keepOthers: true);
        }catch(e, stack){
          Fluttertoast.showToast(
              msg: '发生了错误,任务已经停止',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0);
          print(e);
        }



        count++;
        await showNotification(
        "正在嵌入标签", '当前进度: $count/${playList.musics.length}');
        await Future.delayed(const Duration(milliseconds: 100));


    }

  }

  check(PlayListInfo playList) async {
    var fileList = Directory(playList.path).list();
    var newPlayList = PlayListInfo(
        name: playList.name,
        id: playList.id,
        path: playList.path,
        picUrl: playList.picUrl,
        musics: {});
    var names = [];
    await for (FileSystemEntity fileSystemEntity in fileList) {
      if (FileSystemEntity.typeSync(fileSystemEntity.path) ==
          FileSystemEntityType.file) {

        names.add(p.basenameWithoutExtension(fileSystemEntity.path));
      }
    }

    print("playList music length ==> ${playList.musics.length}");
    print("names length ==> ${names.length}");

    // 本地所缺失的
    var temp = playList.musics.values
        .where((m) => !names.any((e) => m.name == e))
        .toList();
    // 本地所多出的
    var temp1 = names.where((e) =>
        !playList.musics.values.any((m) => m.name == e));
    print("temp length ==> ${temp.length.toString()}");
    print("temp1 length ==> ${temp1.length}");
    Map<String, Music> tempMap = {};
    for (var element in temp) {
      print("temp ==> ${element.name}");
      tempMap[element.id] = element;
    }
    for (var element in temp1) {
      print("temp1 ==> ${element}");
    }

    if (temp.isNotEmpty) {
      var result = await Utils.alertDialog(context, '有文件缺失', '是否现在下载');
      if (result == "T") {
        newPlayList.musics.addAll(tempMap);
        await API().getMusicUrl(newPlayList);
        await download(newPlayList);
        await writeTag(newPlayList);
      } else {
        Fluttertoast.showToast(
            msg: '您已取消下载',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0);
      }
    }
  }

  Future<List<LocalPlayList>> getLocalPlayList() async {
    await initNotification();
    await _loadPrefs();
    var path = prefs.getString('path') ?? defaultPath;
    return await _getLocalPlayList(path);
  }

  Future<List<LocalPlayList>> _getLocalPlayList(String path) async {
    Stream<FileSystemEntity> fileList = Directory(path).list();
    List<LocalPlayList> jsonFileList = [];
    await for (FileSystemEntity fileSystemEntity in fileList) {
      if (FileSystemEntity.typeSync(fileSystemEntity.path) ==
              FileSystemEntityType.file &&
          fileSystemEntity.path.length > 4 &&
          fileSystemEntity.path.substring(fileSystemEntity.path.length - 4) ==
              "json") {
        var file = File(fileSystemEntity.path);
        var jsonData = jsonDecode(file.readAsStringSync());

        var temp = PlayListInfo.fromJson(jsonData);
        var subheading =
            '${temp.musics.length}/${(await API().getPlayListCount(temp.id)).toString()}';
        jsonFileList.add(LocalPlayList(
            name: temp.name,
            id: temp.id,
            path: temp.path,
            picUrl: temp.picUrl,
            subheading: subheading));
      }
    }
    return jsonFileList;
  }

  download(PlayListInfo playList) async {
    var count = 0;
    for (var e in playList.musics.values) {
      if (e.fileType == '') {
        print("url 异常 ${e.name} --${e.id}");
        continue;
      }
      var filePath = '${playList.path}${e.name}.${e.fileType}';
      var file = File(filePath);
      if (file.existsSync()) {
        continue;
      }
      if (e.url == "") {
        print("url is null ${e.name} -- ${e.id}");
        continue;
      }
      var response = await http.get(Uri.parse(e.url));
      file.writeAsBytesSync(response.bodyBytes);

      count++;
      await showNotification('正在下载', "当前进度: $count/${playList.musics.length}");
    }
  }
}
