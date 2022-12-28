// ignore_for_file: constant_identifier_names

class SignInData {
  final bool passLoginWrong;
  final bool obscure;
  final bool progress;
  final bool loginInvalid;

  const SignInData({this.passLoginWrong = false, this.obscure = true, this.progress = false, this.loginInvalid = false});

  SignInData copyWith({bool? obscure, bool? progress, bool? loginInvalid, bool? passLoginWrong}) => SignInData(
      obscure: obscure ?? this.obscure,
      progress: progress ?? this.progress,
      loginInvalid: loginInvalid ?? this.loginInvalid,
      passLoginWrong: passLoginWrong ?? this.passLoginWrong);

  @override
  String toString() {
    return 'SignInData{passLoginWrong: $passLoginWrong, obscure: $obscure, progress: $progress, loginInvalid: $loginInvalid}';
  }
}
