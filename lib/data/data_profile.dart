class ProfileData {
  final String login;
  final bool nameEmpty;

  const ProfileData({this.login = '', this.nameEmpty = false});

  ProfileData copyWith({bool? nameEmpty}) => ProfileData(login: login, nameEmpty: nameEmpty ?? this.nameEmpty);

  @override
  String toString() {
    return 'ProfileData{login: $login}';
  }
}
