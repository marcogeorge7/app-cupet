import 'package:equatable/equatable.dart';

class Country extends Equatable {
  const Country({
    required this.name,
    required this.iso,
    required this.dialCode,
    required this.flag,
  });

  final String name;
  final String iso;
  final String dialCode;
  final String flag;

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: json['name'] as String,
      iso: json['iso'] as String,
      dialCode: json['dial_code'] as String,
      flag: (json['flag'] as String?) ?? '',
    );
  }

  @override
  List<Object?> get props => [name, iso, dialCode, flag];
}

/// Built-in list used when the backend list can't be fetched (e.g. no
/// connectivity on the very first launch). Keeps the user able to log in
/// rather than blocking the auth flow on a config request.
const kFallbackCountries = <Country>[
  Country(name: 'Egypt', iso: 'EG', dialCode: '+20', flag: '🇪🇬'),
  Country(name: 'Saudi Arabia', iso: 'SA', dialCode: '+966', flag: '🇸🇦'),
  Country(name: 'United Arab Emirates', iso: 'AE', dialCode: '+971', flag: '🇦🇪'),
  Country(name: 'United States', iso: 'US', dialCode: '+1', flag: '🇺🇸'),
  Country(name: 'United Kingdom', iso: 'GB', dialCode: '+44', flag: '🇬🇧'),
];
