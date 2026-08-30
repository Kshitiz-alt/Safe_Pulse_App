import 'onboarding_info.dart';

class OnboardingItems {
  List<OnboardingInfo> items = [
    OnboardingInfo(
      title: "Real-Time GPS Tracking",
      descriptions:
          "Track your child’s location in real time and view their route history for added safety.",
      image: "assets/gps.gif",
    ),
    OnboardingInfo(
      title: "Geofencing & Alerts",
      descriptions:
          "Set safe zones like home or school and receive alerts when your child enters or leaves these areas.",
      image: "assets/child2.gif",
    ),
    OnboardingInfo(
      title: "SOS & Emergency Features",
      descriptions:
          "One-tap SOS button lets your child send emergency alerts with their real-time location instantly.",
      image: "assets/emergency.gif",
    ),
    OnboardingInfo(
      title: "Secure Parent-Child Communication",
      descriptions:
          "Stay connected with secure messaging and quick response buttons for instant updates.",
      image: "assets/parents.gif",
    ),
  ];
}
