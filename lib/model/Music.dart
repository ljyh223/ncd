
class Music {
  String album;
  String url;
  String fileType;
  String id;
  String name;
  String picUrl;
  String singer;

  Music({
    required this.album,
    required this.url,
    required this.fileType,
    required this.id,
    required this.name,
    required this.picUrl,
    required this.singer,
  });

  factory Music.fromJson(Map<String, dynamic> json) => Music(
    album: json["album"],
    url: json["url"],
    fileType: json["file_type"],
    id: json["id"],
    name: json['name'],
    picUrl: json["pic_url"],
    singer: json["singer"],
  );

  Map<String, dynamic> toJson() => {
    "album": album,
    "url": url,
    "file_type": fileType,
    "id": id,
    "name": name,
    "pic_url": picUrl,
    "singer": singer,
  };
}
