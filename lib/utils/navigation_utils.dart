import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/notifications_screen.dart';
// import '../screens/community_screen.dart'; // Assuming you have this
// import '../screens/profile_screen.dart'; // Assuming you have this

void navigateToScreen(BuildContext context, int index) {
  // This is a simple navigation handler.
  // You might want to use a more sophisticated navigation solution like go_router
  // for a real application.
  
  // Avoid navigating to the same screen
  final currentRoute = ModalRoute.of(context)?.settings.name;

  switch (index) {
    case 0:
      // Navigate to Home
      if (currentRoute != '/') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
      break;
    case 1:
      // Navigate to Community (assuming a screen exists)
      // Example:
      // if (currentRoute != '/community') {
      //   Navigator.of(context).pushNamed('/community');
      // }
      break;
    case 2:
      // Navigate to Notifications
       if (currentRoute != '/notifications') {
         Navigator.of(context).push(
           MaterialPageRoute(builder: (context) => const NotificationsScreen()),
         );
       }
      break;
    case 3:
      // Navigate to Profile (which is a tab on HomeScreen)
      // We can navigate to home and pass an argument to select the tab.
      if (currentRoute != '/') {
         Navigator.of(context).pushAndRemoveUntil(
           MaterialPageRoute(
             builder: (context) => const HomeScreen(/* initialTabIndex: 3 */), // You'd need to modify HomeScreen to accept this
           ),
           (route) => false,
         );
      } else {
        // If already on home screen, just switch the tab.
        // This logic should ideally be in the HomeScreen itself.
      }
      break;
  }
} 