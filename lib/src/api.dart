import 'dart:convert';

import 'package:ncd/model/Music.dart';
import 'package:ncd/model/PlayList.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/Utils.dart';

class API {
  Future<PlayListInfo> getAllMusic(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var host =
        prefs.getString("server") ?? "neteasecloudmusicapi-five-chi.vercel.app";

    var url = Uri.http(host, 'playlist/detail', {'id': id});

    var resp = await http.get(url);
    var result = jsonDecode(resp.body);
    var playListName = result["playlist"]["name"];
    var playListPicUrl = result["playlist"]["coverImgUrl"];
    int total = result["playlist"]["trackCount"];

    Map<String, Music> musics = {};


    for (int i = 0; i < (total ~/ 50) + 1; i++) {
      url = Uri.http(host, "playlist/track/all",
          {'id': id, 'limit': '50', 'offset': (i * 50).toString()});
      var resp = await http.get(url);
      Map<String, dynamic> result = jsonDecode(resp.body);
      for (var e in List.from(result["songs"])) {
        var singer =
        Utils.getName(List.from(e['ar']).map((e) => e['name']).toList());
        var name = '$singer - ${Utils.specialStrRe(e['name'])}';
        musics[e['id'].toString()] = Music(
            album: e["al"]["name"],
            url: '',
            fileType: '',
            id: e["id"].toString(),
            name: name,
            picUrl: e["al"]["picUrl"],
            singer: singer);
      }
    }
    var path=prefs.getString('path');
    return PlayListInfo(
        name: playListName,
        id: id,
        path: '$path$playListName/',
        picUrl: playListPicUrl,
        musics: musics);
  }

  Future<int> getPlayListCount(String id)async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var host =
        prefs.getString("server") ?? "neteasecloudmusicapi-five-chi.vercel.app";


    var url = Uri.http(host, 'playlist/detail', {'id': id});

    var resp = await http.get(url);
    var result = jsonDecode(resp.body);
    int total = result["playlist"]["trackCount"];

    return total;
  }

  Future<void> getMusicUrl(PlayListInfo p) async {
    if(p.musics.isEmpty) return print("Music is empty");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var cookie = prefs.getString('cookie') ?? '';
    if (cookie == '') {
      print("你妈,cookie 都不准备好");
      return;
    }

    var host =
        prefs.getString("server") ?? "neteasecloudmusicapi-five-chi.vercel.app";
    var ids = p.musics.keys.toList();
    var url = Uri.http(
        host, 'song/url/v1', {'id': ids.join(','), 'level': 'lossless'});

    var resp = await http.get(url, headers: {
      'cookie': 'NMTID=00OBVkpj22k52MZ90o6hMgLxIUEbKMAAAGPr_NCYw; __csrf=ded0f69e4d2362bfcc28b0467d8f8575; MUSIC_U=$cookie'
    });
    var result = jsonDecode(resp.body);

    for (var eu in List.from(result['data'])) {
      var id = eu['id'].toString();
      var url = eu['url'].toString();
      var pop = url
          .split('.')
          .last;
      if (pop != '.') {
        p.musics[id]?.url = url;
        p.musics[id]?.fileType = pop;
      }
    }
  }

  Future<String> getLyric(id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var host =
        prefs.getString("server") ?? "neteasecloudmusicapi-five-chi.vercel.app";
    var url = Uri.http(host, 'lyric', {'id': id});

    var resp = await http.get(url);

    Map<String, dynamic> lyric = jsonDecode(resp.body);
    if (!lyric.containsKey('tlyric') || lyric['tlyric']['lyric']!.isEmpty) return lyric['lrc']['lyric'];

    var lyric0 = lyric['lrc']['lyric'];
    var tlyric = lyric['tlyric']['lyric'];
    var tlyricMap = {};
    var merged = "";
    for (var line in tlyric!.split('\n')) {
      var parts = line.split(']');
      if (parts[0].isEmpty) continue;
      var time = parts[0].substring(1, parts[0].length);
      var text = parts[1];
      tlyricMap[time] = text;
    }

    for (var line in lyric0!.split('\n')) {
      var parts = line.split(']');
      if (parts[0].isEmpty) continue;
      var time = parts[0].substring(1, parts[0].length);
      var text = parts[1];
      if (tlyricMap.containsKey(time)) {
        merged += "[$time]$text\n[$time]${tlyricMap[time]}\n";
      } else {
        merged += "[$time]$text\n";
      }
    }
    return merged;
  }


  Future<String> uerAccount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var cookie = prefs.getString('cookie') ?? '';
    var host =
        prefs.getString("server") ?? "neteasecloudmusicapi-five-chi.vercel.app";
    var url = Uri.http(host, 'user/account');
    var resp = await http.get(url, headers: {'cookie': 'NMTID=00OBVkpj22k52MZ90o6hMgLxIUEbKMAAAGPr_NCYw; __csrf=ded0f69e4d2362bfcc28b0467d8f8575; MUSIC_U=$cookie'});

    var result = jsonDecode(resp.body);
    if (result['code'] == 200 && result['profile'] != null) {
      return result['profile']['nickname'].toString();
    }
    return "";
  }
}