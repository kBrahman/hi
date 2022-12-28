class ProfileData {
  final String login;
  final bool nameEmpty;
  final bool startChat;

  const ProfileData({this.login = '', this.nameEmpty = false, this.startChat = false});

  ProfileData copyWith({bool? startChat, bool? nameEmpty, String? name}) =>
      ProfileData(login: login, startChat: startChat ?? this.startChat, nameEmpty: nameEmpty ?? this.nameEmpty);

  @override
  String toString() {
    return 'ProfileData{login: $login}';
  }
}
