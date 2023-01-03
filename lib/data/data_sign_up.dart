// ignore_for_file: constant_identifier_names

class SignUpData {
  final bool progress;
  final SignUpState state;
  final int focusIndex;
  final int time;
  final bool codeInvalid;
  final bool obscure;
  final bool phoneInvalid;
  final bool pop;
  final bool tooMany;

  const SignUpData(
      {this.state = SignUpState.PHONE,
      this.progress = false,
      this.focusIndex = 0,
      this.time = 0,
      this.codeInvalid = false,
      this.obscure = true,
      this.phoneInvalid = false,
      this.pop = false,
      this.tooMany = false});

  SignUpData copyWith(
          {bool? progress,
          SignUpState? state,
          int? focusIndex,
          int? time,
          bool? codeInvalid,
          bool? obscure,
          bool? phoneInvalid,
          bool? pop,
          bool? tooMany}) =>
      SignUpData(
          progress: progress ?? this.progress,
          state: state ?? this.state,
          focusIndex: focusIndex ?? this.focusIndex,
          time: time ?? this.time,
          codeInvalid: codeInvalid ?? this.codeInvalid,
          obscure: obscure ?? this.obscure,
          phoneInvalid: phoneInvalid ?? this.phoneInvalid,
          pop: pop ?? this.pop,
          tooMany: tooMany ?? this.tooMany);

  @override
  String toString() {
    return 'SignUpData{time: $time}';
  }
}

enum SignUpState { SMS, PHONE, SAVE }
