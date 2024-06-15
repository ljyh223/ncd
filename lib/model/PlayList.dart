import 'dart:convert';

import 'Music.dart';

class PlayListInfo {
  String name;
  String id;
  String path;
  String picUrl;
  Map<String, Music> musics;

  PlayListInfo(
      {required this.name,
      required this.id,
      required this.path,
      required this.picUrl,
      required this.musics});

  factory PlayListInfo.fromJson(Map<String, dynamic> json) {
    Map<String, Music> musicsMap = {};
    if (json['musics'] != null) {
      json['musics'].forEach((key, value) {
        musicsMap[key] = Music.fromJson(value);
      });
    }
    return PlayListInfo(
        name: json["name"],
        id: json["id"],
        path: json["path"],
        picUrl: json["pic_url"],
        musics: musicsMap);
  }

  PlayListInfo deepCopy() {
    // 将当前对象转换为JSON字符串
    String jsonString = jsonEncode(toJson());
    // 从JSON字符串反序列化生成一个新的PlayListInfo实例
    var copiedJson = jsonDecode(jsonString);

    // 对于musics中的每个Music对象，也需要确保是深拷贝
    // Map<String, dynamic> copiedMusics = {};
    // copiedJson['musics']?.forEach((key, value) {
    //
    //   copiedMusics[key] = Music.fromJson(value); // 假设Music类也有fromJson方法
    // });
    // copiedJson['musics'] = copiedMusics;

    return PlayListInfo.fromJson(copiedJson);
  }

  Map<String, dynamic> toJson() {
    var musicsMap = {};
    musics.forEach((key, value) {
      musicsMap[key] = value.toJson();
    });
    return {
      "name": name,
      "id": id,
      "path": path,
      "pic_url": picUrl,
      "musics": musicsMap
    };
  }
}
