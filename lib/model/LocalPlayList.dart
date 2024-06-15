
class LocalPlayList {
  String name;
  String id;
  String path;
  String picUrl;

  String subheading;

  LocalPlayList({
    required this.name,
    required this.id,
    required this.path,
    required this.picUrl,
    required this.subheading
  });

  factory LocalPlayList.fromJson(Map<String, dynamic> json) =>LocalPlayList(

    name: json["name"],
    id: json["id"],
    path: json["path"],
    picUrl: json["pic_url"],
    subheading:json['subheading']

  );
  Map<String, dynamic> toJson() => {
    "name": name,
    "id": id,
    "path": path,
    "pic_url": picUrl,
    "subheading":subheading
  };
}
