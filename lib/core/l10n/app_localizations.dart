import 'package:flutter/material.dart';

/// Externalized localization for English ('en') and Hinglish ('hi').
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [Locale('en'), Locale('hi')];

  bool get isHinglish => locale.languageCode == 'hi';

  String t(String key) {
    final map = isHinglish ? _hinglishStrings : _englishStrings;
    return map[key] ?? _englishStrings[key] ?? key;
  }

  static const Map<String, String> _englishStrings = {
    'app_name': 'DESI GUESS',
    'hero_headline': 'Ready to test your guessing skills?',
    'hero_subtitle':
        'Outsmart your opponent across Bollywood, Cricket, Street Food & iconic Indian places.',
    'play_online': 'PLAY ONLINE',
    'play_together': 'PLAY TOGETHER',
    'play_online_sub': 'Challenge friends remotely with live chat',
    'play_together_sub': 'Pass & play on one phone, no internet needed',
    'featured_categories': 'Featured Categories',
    'recently_played': 'Recently Played Packs',
    'daily_challenge': 'Daily Desi Challenge',
    'daily_challenge_sub': 'Play Bollywood Legends & keep your streak alive!',
    'leaderboard_preview': 'Top Guessers',
    'your_stats': 'Your Stats',
    'see_all': 'See All',
    'cat_who': 'WHO',
    'cat_who_desc': 'Icons, cricketers, stars & legends (25+ cards)',
    'cat_what': 'WHAT',
    'cat_what_desc': 'Desi food, brands, movies & tech (15+ cards)',
    'cat_where': 'WHERE',
    'cat_where_desc': 'Cities, monuments & dream trips (10+ cards)',
    'cat_custom': 'CUSTOM',
    'cat_custom_desc': 'Create & play your own private boards',
    'nav_home': 'Home',
    'nav_play': 'Play',
    'nav_boards': 'Boards',
    'nav_ranks': 'Ranks',
    'nav_profile': 'Profile',
    'login': 'Sign In',
    'register': 'Create Account',
    'guest_login': 'Continue as Guest',
    'welcome_back': 'Welcome Back',
    'select_secret_card': 'Pick Your Secret Card',
    'secret_hint':
        'Tap any card below. Your opponent will try to guess this card!',
    'confirm_secret': 'Lock Secret Card',
    'handoff_title': 'Pass the Phone',
    'handoff_subtitle': 'Make sure the other player cannot see the screen.',
    'im_ready': 'I Am Ready',
    'make_final_guess': 'Final Guess',
    'your_turn': 'Your Turn',
    'opponent_turn': 'Opponent\'s Turn',
    'remaining_cards': 'Remaining',
    'eliminated': 'Eliminated',
    'tap_to_eliminate': 'Tap cards to eliminate or restore',
    'view_my_secret': 'Hold to Peek Secret',
    'victory_title': 'VICTORY!',
    'defeat_title': 'OUT OF HEARTS!',
    'rematch': 'Rematch',
    'back_home': 'Back to Home',
    'create_room': 'Create Room',
    'join_room': 'Join Room',
    'enter_room_code': 'Enter 6-character code',
    'share_invite': 'Share Invite Code',
    'waiting_opponent': 'Waiting for opponent to join...',
    'yes': 'Yes',
    'no': 'No',
    'ask_question_hint': 'Ask a yes/no question...',
    'question_history': 'Question History',
    'settings': 'Settings',
    'sound_effects': 'Sound Effects',
    'vibration': 'Haptic Vibration',
    'background_music': 'Ambient Music',
    'dark_theme': 'Dark Premium Theme',
    'language': 'Language',
    'help_and_rules': 'Help & Rules',
    'friends_invites': 'Friends & Invites',
    'custom_board_creator': 'Custom Boards',
    'create_board': 'Create New Board',
    'add_card': 'Add Card',
    'resume_match': 'Resume Local Match',
    'hearts_left': 'Hearts Left',
    'questions_asked': 'Questions',
    'wrong_guesses': 'Wrong Guesses',
    'match_duration': 'Duration',
  };

  static const Map<String, String> _hinglishStrings = {
    'app_name': 'DESI GUESS',
    'hero_headline': 'Guessing skills test karne ke liye ready ho?',
    'hero_subtitle':
        'Bollywood, Cricket, Street Food aur Desi jagahon mein opponent ko harao!',
    'play_online': 'ONLINE KHELO',
    'play_together': 'SAATH KHELO',
    'play_online_sub': 'Doston ke saath live chat mein khelo',
    'play_together_sub': 'Ek hi phone par pass & play, bina internet',
    'featured_categories': 'Khaas Categories',
    'recently_played': 'Haal Hi Mein Khele Packs',
    'daily_challenge': 'Aaj Ka Desi Challenge',
    'daily_challenge_sub': 'Bollywood Legends khelo aur streak banao!',
    'leaderboard_preview': 'Top Khiladi',
    'your_stats': 'Tumhare Stats',
    'see_all': 'Sab Dekho',
    'cat_who': 'KAUN (WHO)',
    'cat_who_desc': 'Cricketers, actors, stars aur legends (25+ cards)',
    'cat_what': 'KYA (WHAT)',
    'cat_what_desc': 'Desi khana, brands, movies aur cheezein (15+ cards)',
    'cat_where': 'KAHAN (WHERE)',
    'cat_where_desc': 'Shehar, monuments aur ghoomne ki jagah (10+ cards)',
    'cat_custom': 'APNA BOARD',
    'cat_custom_desc': 'Khud ke private boards aur cards banao',
    'nav_home': 'Home',
    'nav_play': 'Khelo',
    'nav_boards': 'Boards',
    'nav_ranks': 'Ranks',
    'nav_profile': 'Profile',
    'login': 'Sign In Karo',
    'register': 'Naya Account Banao',
    'guest_login': 'Guest Banke Khelo',
    'welcome_back': 'Wapas Swagat Hai',
    'select_secret_card': 'Apna Secret Card Chuno',
    'secret_hint':
        'Neeche se koi card tap karo. Opponent ko yehi guess karna hai!',
    'confirm_secret': 'Secret Card Lock Karo',
    'handoff_title': 'Phone Doosre Ko Do',
    'handoff_subtitle': 'Dhyaan rakho doosra player screen na dekh sake.',
    'im_ready': 'Main Ready Hoon',
    'make_final_guess': 'Final Guess Karo',
    'your_turn': 'Tumhari Baari',
    'opponent_turn': 'Opponent Ki Baari',
    'remaining_cards': 'Bache Hue',
    'eliminated': 'Hataye Hue',
    'tap_to_eliminate': 'Card hatane ya wapas laane ke liye tap karo',
    'view_my_secret': 'Secret Dekhne Ke Liye Dabaye Rakho',
    'victory_title': 'JEET GAYE!',
    'defeat_title': 'HEARTS KHATAM!',
    'rematch': 'Phir Se Khelo',
    'back_home': 'Home Par Jao',
    'create_room': 'Room Banao',
    'join_room': 'Room Join Karo',
    'enter_room_code': '6-letter code daalo',
    'share_invite': 'Invite Code Share Karo',
    'waiting_opponent': 'Opponent ke aane ka intezaar...',
    'yes': 'Haan',
    'no': 'Nahi',
    'ask_question_hint': 'Haan/Nahi wala sawaal poocho...',
    'question_history': 'Sawaalon Ka Itihaas',
    'settings': 'Settings',
    'sound_effects': 'Sound Effects',
    'vibration': 'Vibration',
    'background_music': 'Background Music',
    'dark_theme': 'Dark Premium Theme',
    'language': 'Bhasha (Language)',
    'help_and_rules': 'Niyam Aur Madad',
    'friends_invites': 'Dost Aur Invites',
    'custom_board_creator': 'Apne Boards',
    'create_board': 'Naya Board Banao',
    'add_card': 'Card Jodo',
    'resume_match': 'Purana Match Jaari Rakho',
    'hearts_left': 'Bache Hearts',
    'questions_asked': 'Sawaal',
    'wrong_guesses': 'Galat Guess',
    'match_duration': 'Samay',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
