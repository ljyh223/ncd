import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../src/api.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPage createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> {
  String savePath = defaultPath;

  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    // 在界面初始化时从SharedPreferences中读取开关的状态
    _loadSwitchValue();
  }

  _loadSwitchValue() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      savePath = prefs.getString('save_path') ?? defaultPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(children: [
      const TextInputSettingsTile(
        title: 'Cookie',
        settingKey: 'cookie',
        helperText: 'your netease cloud music cookie.',
        borderColor: Colors.blueAccent,
        errorColor: Colors.deepOrangeAccent,
      ),
      TextInputSettingsTile(
        title: 'Server',
        settingKey: 'server',
        // initialValue: 'https://neteasecloudmusicapi-five-chi.vercel.app/',
        helperText: 'neteasecloudmusicapi server host.',
        validator: (username) {
          return;
        },
        borderColor: Colors.blueAccent,
        errorColor: Colors.deepOrangeAccent,
      ),
      SimpleSettingsTile(
          title: 'Save Path',
          subtitle: savePath,
          showDivider: false,
          onTap: () async {
            var path = await openAndSelectDirectory();
            setState(() {
              savePath = path;
            });
            prefs.setString("path", path);
            print(path);
            Fluttertoast.showToast(
                msg: path,
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.green,
                textColor: Colors.white,
                fontSize: 16.0);
          }),
      SimpleSettingsTile(title: 'Click me to test',
        subtitle: 'Test for cookie and domain availability',
        showDivider: false,
        onTap: () async {
          try {
            API().uerAccount().then((value) =>
            {
              Fluttertoast.showToast(
                  msg: value == '' ? 'cookie 似乎不可用' : 'hello $value',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                  backgroundColor: value == '' ? Colors.orange : Colors.green,
                  textColor: Colors.white,
                  fontSize: 16.0)
            });
          } catch (e) {
            Fluttertoast.showToast(
                msg: '你的service似乎不可用',
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor:  Colors.orange ,
                textColor: Colors.white,
                fontSize: 16.0);
            print(e);
          }
        },)
    ]);
  }
}

Future<String> openAndSelectDirectory() async {
  var status = await Permission.manageExternalStorage.status;
  if (status.isGranted) {
    if (!await requestStoragePermission()) {
      Fluttertoast.showToast(
          msg: "您拒绝了访问所有文件的权限",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }
  try {
    // 使用file_picker选择目录
    String? directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath != null) {
      return '$directoryPath/';
    } else {
      print('cancel');
      return "";
    }
  } catch (e) {
    print("error");
    return "";
  }
}

Future<bool> requestStoragePermission() async {
  var status = await Permission.manageExternalStorage.status;
  if (!status.isGranted) {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.manageExternalStorage,
    ].request();
    return statuses[Permission.manageExternalStorage] ==
        PermissionStatus.granted;
  } else {
    return true;
  }
}

Future<void> requestStoragePermissionDemo() async {
  if (Platform.isAndroid) {
    var androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 30) {
      print('>=30');
      // Android 11及以上版本
      PermissionStatus status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        print('>30 request');
        await Permission.manageExternalStorage.request();
      }
    } else {
      // Android 10及以下版本
      print("<30");
      PermissionStatus readStatus = await Permission.storage.status;
      await [Permission.storage, Permission.manageExternalStorage].request();
      if (!readStatus.isGranted) {
        print("<30 request");
        await Permission.storage.request();
      }
    }
  }
}
