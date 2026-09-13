// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'डॉक्टरबुक';

  @override
  String get welcomeTitle => 'डॉक्टरबुक में\nस्वागत है';

  @override
  String get welcomeSubtitle => 'शुरू करने के लिए अपना मोबाइल नंबर डालें';

  @override
  String get sendOtp => 'OTP भेजें';

  @override
  String get continueWithGoogle => 'Google से जारी रखें';

  @override
  String get orDivider => 'या';

  @override
  String get phoneRequired => 'फोन नंबर जरूरी है';

  @override
  String get phoneInvalid => '10 अंकों का वैध नंबर डालें';

  @override
  String get findDoctor => 'डॉक्टर खोजें';

  @override
  String get goodMorning => 'सुप्रभात 👋';

  @override
  String get goodAfternoon => 'नमस्ते 👋';

  @override
  String get goodEvening => 'शुभ संध्या 👋';

  @override
  String get nearbyDoctors => 'नजदीकी डॉक्टर';

  @override
  String get seeAll => 'सभी देखें';

  @override
  String get searchPlaceholder => 'डॉक्टर, विशेषता खोजें...';

  @override
  String get bookFirstAppointment => 'अपना पहला\nअपॉइंटमेंट बुक करें';

  @override
  String get findDoctorsNearYou => 'नजदीकी डॉक्टर खोजें';

  @override
  String get experience => 'अनुभव';

  @override
  String get reviews => 'समीक्षाएं';

  @override
  String get fee => 'शुल्क';

  @override
  String get about => 'परिचय';

  @override
  String get qualifications => 'योग्यताएं';

  @override
  String get languages => 'भाषाएं';

  @override
  String get clinic => 'क्लिनिक';

  @override
  String get clinicGallery => 'क्लिनिक गैलरी';

  @override
  String get availableDates => 'उपलब्ध तिथियां';

  @override
  String get addRecord => 'रिकॉर्ड जोड़ें';

  @override
  String get addFirstRecord => 'पहला रिकॉर्ड जोड़ें';

  @override
  String get medicalHistory => 'चिकित्सा इतिहास';

  @override
  String get noMedicalRecords => 'कोई चिकित्सा रिकॉर्ड नहीं';

  @override
  String get medicalHistorySubtitle =>
      'अपनी बीमारियों, एलर्जी, दवाओं आदि का रिकॉर्ड रखें।';

  @override
  String get recordType => 'प्रकार';

  @override
  String get recordTitle => 'शीर्षक';

  @override
  String get recordDetails => 'विवरण (वैकल्पिक)';

  @override
  String get recordDate => 'तिथि (वैकल्पिक)';

  @override
  String get saveRecord => 'रिकॉर्ड सहेजें';

  @override
  String get saving => 'सहेज रहे हैं…';

  @override
  String get deleteRecord => 'रिकॉर्ड हटाएं?';

  @override
  String get deleteRecordMessage =>
      'यह रिकॉर्ड आपके इतिहास से स्थायी रूप से हटा दिया जाएगा।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get delete => 'हटाएं';

  @override
  String get recordDeleted => 'रिकॉर्ड हटाया गया';

  @override
  String get failedToDelete => 'रिकॉर्ड हटाने में विफल';

  @override
  String get failedToSave => 'रिकॉर्ड सहेजने में विफल';

  @override
  String get condition => 'बीमारी';

  @override
  String get allergy => 'एलर्जी';

  @override
  String get medication => 'दवा';

  @override
  String get surgery => 'सर्जरी';

  @override
  String get vaccination => 'टीकाकरण';

  @override
  String get note => 'नोट';

  @override
  String get mapTitle => 'नजदीकी डॉक्टर';

  @override
  String get getDirections => 'दिशा-निर्देश';

  @override
  String get viewProfileBook => 'प्रोफ़ाइल देखें और बुक करें';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get editProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get savedDoctors => 'सहेजे गए डॉक्टर';

  @override
  String get notifications => 'सूचनाएं';

  @override
  String get darkMode => 'डार्क मोड';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get termsOfService => 'सेवा की शर्तें';

  @override
  String get contactSupport => 'सहायता से संपर्क करें';

  @override
  String get signOut => 'साइन आउट';

  @override
  String get termsMessage =>
      'जारी रखकर आप हमारी सेवा की शर्तों\nऔर गोपनीयता नीति से सहमत हैं';

  @override
  String bookOn(String date) {
    return '$date को बुक करें';
  }

  @override
  String yearExperience(int n) {
    return '$n वर्ष';
  }
}
