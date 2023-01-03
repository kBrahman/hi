class EmailSignInData {
  final bool progress;
  final bool emailInvalid;
  final bool emailSent;

  const EmailSignInData({this.progress = false, this.emailInvalid = false, this.emailSent = false});

  EmailSignInData copyWith({bool? progress, bool? emailInvalid, bool? emailSent}) => EmailSignInData(
      progress: progress ?? this.progress,
      emailInvalid: emailInvalid ?? this.emailInvalid,
      emailSent: emailSent ?? this.emailSent);
}
