import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Utils {
  static getName(List<dynamic> artists) {
    String artist;
    if (artists.length <= 3) {
      artist = artists.join(' ');
    } else {
      artist = artists.sublist(0, 3).join(' ');
    }
    return specialStrRe(artist);
  }

  static String specialStrRe(String str) {
    //* /：<>？\ | +，。; = []
    var special = [
      ["<", "＜"],
      [">", "＞"],
      ["\\", "＼"],
      ["/", "／"],
      [":", "："],
      ["?", "？"],
      ["*", "＊"],
      ["\"", "＂"],
      ["|", "｜"],
      [',', '，'],
      [';', '；'],
      ['=', '＝'],
      ["...", " "]
    ];

    return special.fold(str, (acc, e) => acc.replaceAll(e[0], e[1]));
  }

  static Future<Uint8List> getImage(url) async {
    var result = await http.get(Uri.parse(url), headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:126.0) Gecko/20100101 Firefox/126.0'
    });
    return result.bodyBytes;
  }

  static Future<String> alertDialog(
      BuildContext context, String title, String content) async {
    var result = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.pop(context, 'F');
                },
              ),
              TextButton(
                  child: const Text("OK"),
                  onPressed: () {
                    Navigator.pop(context, "T");
                  })
            ],
          );
        });

    return result;
  }

  static isInternalNetwork(String url) {
    final uri = Uri.parse(url);
    final ip = InternetAddress.tryParse(uri.host);
    // 这里可以根据实际情况调整内网IP段判断条件
    return ip != null &&
        (ip.isLoopback ||
            ip.address.startsWith('192.168.') ||
            ip.address.startsWith('10.'));
  }

  static Uri parseUrlWithScheme(String host, String path,
      [Map<String, dynamic>? parms]) {
    if (isInternalNetwork(host)) {
      // 如果是内网环境，使用http
      return Uri.http(host, path, parms);
    } else {
      // 非内网环境使用https
      return Uri.https(host, path, parms);
    }
  }
}
