enum ProfileGender {
  men,
  women,
}

enum LookingForGender {
  men,
  women,
  any,
}

enum LookingForIntent {
  date,
  makeFriends,
  networking,
  professionalDevelopment,
}

extension LookingForIntentLabel on LookingForIntent {
  String get label => switch (this) {
        LookingForIntent.date => 'Date',
        LookingForIntent.makeFriends => 'Make Friends',
        LookingForIntent.networking => 'Networking',
        LookingForIntent.professionalDevelopment => 'Professional Development',
      };
}

extension ProfileGenderLabel on ProfileGender {
  String get label => switch (this) {
        ProfileGender.men => 'Men',
        ProfileGender.women => 'Women',
      };

  LookingForGender get oppositeLookingFor => switch (this) {
        ProfileGender.men => LookingForGender.women,
        ProfileGender.women => LookingForGender.men,
      };
}

extension LookingForGenderLabel on LookingForGender {
  String get label => switch (this) {
        LookingForGender.men => 'Men',
        LookingForGender.women => 'Women',
        LookingForGender.any => 'Any',
      };
}

class ProfileModel {
  const ProfileModel({
    this.name = '',
    this.age = '',
    this.about = '',
    this.gender,
    this.intents = const {},
    this.dateLookingFor = LookingForGender.any,
    this.friendsLookingFor = LookingForGender.any,
  });

  final String name;
  final String age;
  final String about;
  final ProfileGender? gender;
  final Set<LookingForIntent> intents;
  final LookingForGender dateLookingFor;
  final LookingForGender friendsLookingFor;

  ProfileModel copyWith({
    String? name,
    String? age,
    String? about,
    ProfileGender? gender,
    bool clearGender = false,
    Set<LookingForIntent>? intents,
    LookingForGender? dateLookingFor,
    LookingForGender? friendsLookingFor,
    bool clearDateLookingFor = false,
    bool clearFriendsLookingFor = false,
  }) {
    return ProfileModel(
      name: name ?? this.name,
      age: age ?? this.age,
      about: about ?? this.about,
      gender: clearGender ? null : (gender ?? this.gender),
      intents: intents ?? this.intents,
      dateLookingFor: clearDateLookingFor
          ? LookingForGender.any
          : (dateLookingFor ?? this.dateLookingFor),
      friendsLookingFor: clearFriendsLookingFor
          ? LookingForGender.any
          : (friendsLookingFor ?? this.friendsLookingFor),
    );
  }

  Map<String, String> validate() {
    final errors = <String, String>{};

    if (name.trim().isEmpty) {
      errors['name'] = 'Name is required';
    } else if (name.trim().length < 2) {
      errors['name'] = 'Name must be at least 2 characters';
    } else if (name.trim().length > 50) {
      errors['name'] = 'Name must be at most 50 characters';
    }

    if (age.trim().isEmpty) {
      errors['age'] = 'Age is required';
    } else {
      final parsed = int.tryParse(age.trim());
      if (parsed == null) {
        errors['age'] = 'Enter a valid age';
      } else if (parsed < 18) {
        errors['age'] = 'You must be at least 18';
      } else if (parsed > 120) {
        errors['age'] = 'Enter a valid age';
      }
    }

    if (about.trim().isEmpty) {
      errors['about'] = 'Tell us a bit about yourself';
    } else if (about.trim().length > 500) {
      errors['about'] = 'Keep it under 500 characters';
    }

    if (gender == null) {
      errors['gender'] = 'Select your gender';
    }

    if (intents.isEmpty) {
      errors['intents'] = 'Select at least one option';
    }

    return errors;
  }
}
