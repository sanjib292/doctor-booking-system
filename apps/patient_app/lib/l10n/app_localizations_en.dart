// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'DoctorBook';

  @override
  String get welcomeTitle => 'Welcome to\nDoctorBook';

  @override
  String get welcomeSubtitle => 'Enter your mobile number to get started';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get orDivider => 'or';

  @override
  String get phoneRequired => 'Phone number required';

  @override
  String get phoneInvalid => 'Enter a valid 10-digit number';

  @override
  String get findDoctor => 'Find a Doctor';

  @override
  String get goodMorning => 'Good morning 👋';

  @override
  String get goodAfternoon => 'Good afternoon 👋';

  @override
  String get goodEvening => 'Good evening 👋';

  @override
  String get nearbyDoctors => 'Nearby Doctors';

  @override
  String get seeAll => 'See All';

  @override
  String get searchPlaceholder => 'Search doctors, specialties...';

  @override
  String get bookFirstAppointment => 'Book Your First\nAppointment';

  @override
  String get findDoctorsNearYou => 'Find Doctors Near You';

  @override
  String get experience => 'Experience';

  @override
  String get reviews => 'Reviews';

  @override
  String get fee => 'Fee';

  @override
  String get about => 'About';

  @override
  String get qualifications => 'Qualifications';

  @override
  String get languages => 'Languages';

  @override
  String get clinic => 'Clinic';

  @override
  String get clinicGallery => 'Clinic Gallery';

  @override
  String get availableDates => 'Available Dates';

  @override
  String get addRecord => 'Add Record';

  @override
  String get addFirstRecord => 'Add First Record';

  @override
  String get medicalHistory => 'Medical History';

  @override
  String get noMedicalRecords => 'No Medical Records';

  @override
  String get medicalHistorySubtitle =>
      'Keep track of your conditions, allergies, medications and more.';

  @override
  String get recordType => 'Type';

  @override
  String get recordTitle => 'Title';

  @override
  String get recordDetails => 'Details (optional)';

  @override
  String get recordDate => 'Date (optional)';

  @override
  String get saveRecord => 'Save Record';

  @override
  String get saving => 'Saving…';

  @override
  String get deleteRecord => 'Delete record?';

  @override
  String get deleteRecordMessage =>
      'This record will be permanently removed from your history.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get recordDeleted => 'Record deleted';

  @override
  String get failedToDelete => 'Failed to delete record';

  @override
  String get failedToSave => 'Failed to save record';

  @override
  String get condition => 'Condition';

  @override
  String get allergy => 'Allergy';

  @override
  String get medication => 'Medication';

  @override
  String get surgery => 'Surgery';

  @override
  String get vaccination => 'Vaccination';

  @override
  String get note => 'Note';

  @override
  String get mapTitle => 'Nearby Doctors';

  @override
  String get getDirections => 'Directions';

  @override
  String get viewProfileBook => 'View Profile & Book';

  @override
  String get profile => 'Profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get savedDoctors => 'Saved Doctors';

  @override
  String get notifications => 'Notifications';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get signOut => 'Sign Out';

  @override
  String get termsMessage =>
      'By continuing, you agree to our Terms of Service\nand Privacy Policy';

  @override
  String bookOn(String date) {
    return 'Book on $date';
  }

  @override
  String yearExperience(int n) {
    return '${n}yr';
  }
}
