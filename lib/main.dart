import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

// --- GİRİŞ NOKTASI ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("Başlatma hatası: $e");
  }

  runApp(const RootApp());
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  bool _isLoading = true;
  bool _showRealApp = false;
  bool _isAppEnabled = true; // Varsayılan açık
  String _debugError = ""; 

  @override
  void initState() {
    super.initState();
    _fetchConfig();
  }

  Future<void> _fetchConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      // Default değerler: uygulama açık, gerçek mod kapalı
      await remoteConfig.setDefaults({
        "show_real_app": false,
        "app_enabled": true
      });
      
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, 
      ));
      
      await remoteConfig.fetchAndActivate();

      if (mounted) {
        setState(() {
          _showRealApp = remoteConfig.getBool('show_real_app');
          _isAppEnabled = remoteConfig.getBool('app_enabled');
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showRealApp = false; 
          _isAppEnabled = true; // Hata durumunda uygulamayı açık tut
          _isLoading = false;
          _debugError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white, 
          body: ModernLoader(text: "VERDICT Başlatılıyor...")
        ),
      );
    }

    // BAKIM MODU KONTROLÜ
    if (!_isAppEnabled) {
      return const MaintenanceApp();
    }

    if (_showRealApp) {
      return const UnfollowersApp(); 
    } else {
      return SafeModeApp(debugError: _debugError); 
    }
  }
}

// --- BAKIM MODU EKRANI ---
class MaintenanceApp extends StatelessWidget {
  const MaintenanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF4F7F9),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.build_circle_outlined, size: 80, color: Colors.blueGrey.shade700),
                const SizedBox(height: 20),
                Text(
                  "SİSTEM BAKIMDA",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade800),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Uygulama şu an sunucu bakımındadır. Lütfen daha sonra tekrar deneyiniz veya mağazadan güncellemeleri kontrol ediniz.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ModernLoader extends StatefulWidget {
  final String? text;
  final bool isDark;
  const ModernLoader({super.key, this.text, this.isDark = false});

  @override
  State<ModernLoader> createState() => _ModernLoaderState();
}

class _ModernLoaderState extends State<ModernLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color color = widget.isDark ? Colors.white : Colors.blueGrey;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          SizedBox(
            width: 40, 
            height: 40, 
            child: CircularProgressIndicator(
              strokeWidth: 3, 
              valueColor: AlwaysStoppedAnimation<Color>(color)
            )
          ),
          if (widget.text != null) ...[
            const SizedBox(height: 20),
            Text(
              widget.text!, 
              style: TextStyle(
                color: color.withOpacity(0.8), 
                fontWeight: FontWeight.w600, 
                letterSpacing: 1.0,
                fontSize: 12
              )
            ),
          ]
        ],
      ),
    );
  }
}

class SafeModeApp extends StatelessWidget {
  final String debugError;
  const SafeModeApp({super.key, this.debugError = ""});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: const Color(0xFFC13584), 
        scaffoldBackgroundColor: const Color(0xFFFAFAFA)
      ),
      home: BioPlannerScreen(debugError: debugError),
    );
  }
}

class BioPlannerScreen extends StatefulWidget {
  final String debugError;
  const BioPlannerScreen({super.key, required this.debugError});

  @override
  State<BioPlannerScreen> createState() => _BioPlannerScreenState();
}

class _BioPlannerScreenState extends State<BioPlannerScreen> {
  final TextEditingController _bioCtrl = TextEditingController();
  int _charCount = 0;
  
  final List<String> _popularHashtags = [
    "#love", "#instagood", "#photooftheday", "#fashion", "#beautiful", 
    "#happy", "#cute", "#tbt", "#like4like", "#followme", 
    "#picoftheday", "#follow", "#me", "#selfie", "#summer", 
    "#art", "#instadaily", "#friends", "#repost", "#nature"
  ];

  // AI Yalanı için cümleler
  final List<String> _aiTemplates = [
    "Chasing sunsets and dreams. ✨ #vibes",
    "Coffee in one hand, confidence in the other. ☕",
    "Creating my own sunshine today. ☀️",
    "Just another magic Monday. 💫",
    "Less perfection, more authenticity. 🌿",
    "Collecting moments, not things. 📸",
    "Current mood: Unstoppable. 🚀",
    "Life is short, make it sweet. 🍭"
  ];

  @override
  void initState() {
    super.initState();
    _bioCtrl.addListener(() {
      setState(() {
        _charCount = _bioCtrl.text.length;
      });
    });
  }

  void _generateAiCaption() {
    final random = _aiTemplates[DateTime.now().second % _aiTemplates.length];
    _bioCtrl.text = random;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("AI Caption Generated! ✨"),
      duration: Duration(milliseconds: 800),
      backgroundColor: Colors.deepPurple,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Caption & Tag Gen", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.debugError.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 20),
                color: Colors.red.shade100,
                child: Text("Firebase Error (Gizli): ${widget.debugError}", style: const TextStyle(fontSize: 10, color: Colors.red)),
              ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("AI Caption Generator", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ElevatedButton.icon(
                  onPressed: _generateAiCaption,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text("AI Generate"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade50,
                    foregroundColor: Colors.deepPurple,
                    elevation: 0
                  ),
                )
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  TextField(
                    controller: _bioCtrl,
                    maxLines: 4,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Tap 'AI Generate' or write your own...",
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("$_charCount / 150", style: TextStyle(color: _charCount > 150 ? Colors.red : Colors.grey)),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _bioCtrl.text));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caption copied!")));
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text("Copy"),
                      )
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Text("Trending Tags", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _popularHashtags.map((tag) => ActionChip(
                label: Text(tag),
                backgroundColor: Colors.white,
                elevation: 1,
                onPressed: () {
                  String current = _bioCtrl.text;
                  if (current.isNotEmpty && !current.endsWith(' ')) current += ' ';
                  _bioCtrl.text = current + tag;
                  _bioCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _bioCtrl.text.length));
                },
              )).toList(),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                "Info: AI Models & Tag database updates automatically every 24 hours.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey.withOpacity(0.6), fontStyle: FontStyle.italic),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class UnfollowersApp extends StatelessWidget {
  const UnfollowersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, String> followersMap = {}, followingMap = {}, nonFollowersMap = {}, unfollowersMap = {}, newFollowersMap = {};
  
  Map<String, int> badges = {
    'followers': 0, 'following': 0, 'new_followers': 0, 'non_followers': 0, 'left_followers': 0,
  };
  
  Map<String, Set<String>> newItemsMap = {
    'followers': {}, 'following': {}, 'new_followers': {}, 'non_followers': {}, 'left_followers': {},
  };

  String followersCount = '?', followingCount = '?', nonFollowersCount = '?', leftCount = '?', newCount = '?';
  bool isLoggedIn = false, isProcessing = false, isDarkMode = false;
  String currentUsername = "";
  String? savedCookie, savedUserId, savedUserAgent;

  DateTime? _lastUpdateTimeNetwork;
  Duration? _remainingToNextAnalysis;
  Timer? _countdownTimer;
  Timer? _legalHoldTimer; 

  String _lang = 'tr';

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  String? _bannerAdError;
  String? _currentAdUnit;
  bool _adsHidden = false;

  RewardedAd? _rewardedAd; // Typo fix in variable name if present in original, assuming RewardedAd
  bool _isRewardedLoading = false;

  bool _justWatchedReward = false;

  static const bool _forceTestAds = false; 

  final Map<String, Map<String, String>> _localized = {
    'tr': {
      'tagline': 'Professional Social Media Solutions',
      'adsense_banner': 'REKLAM ALANI',
      'free_app_note': 'Bu uygulama ücretsiz kullanım için tasarlanmıştır, taklitlerimizden sakınınız.',
      'login_prompt': 'Analizi başlatmak için lütfen giriş yapınız.',
      'welcome': 'Hoş geldiniz, {username}',
      'refresh_data': 'VERİLERİ GÜNCELLE',
      'login_with_instagram': 'INSTAGRAM İLE GİRİŞ YAP',
      'fetching_data': 'Veriler analiz ediliyor...\nBu işlem biraz sürebilir.',
      'analysis_secure': 'Analiz işlemleri güvenli bir şekilde cihazınızda gerçekleştirilmektedir.',
      'contact_info': 'Sorularınız, önerileriniz ve destek için Instagram: @grkmcomert',
      'next_analysis': 'Sonraki Analiz',
      'next_analysis_ready': 'Analiz şu anda yapılabilir.',
      'please_wait': 'Lütfen bekleyiniz',
      'remaining_time': 'Kalan süre: {time}',
      'clear_data_title': 'Veri Sıfırlama',
      'clear_data_content': 'Tüm yerel veriler ve oturum bilgileri silinecektir. Emin misiniz?',
      'cancel': 'İPTAL',
      'delete': 'SİL',
      'error_title': 'HATA',
      'data_fetch_error': 'Veri çekilemedi: {err}\n\nÇözüm: Çıkış yapıp tekrar giriş deneyin.',
      'followers': 'Takipçiler',
      'following': 'Takip Ettiklerin',
      'new_followers': 'Yeni Takipçiler',
      'non_followers': 'Geri Takip Etmeyenler',
      'left_followers': 'Takibi Bırakanlar',
      'legal_warning': 'Yasal Uyarı',
      'read_and_agree': 'OKUDUM VE KABUL EDİYORUM',
      'no_data': 'Veri yok',
      'new_badge': 'YENİ',
      'login_title': 'Giriş Yap',
      'redirecting': 'Oturum doğrulandı, yönlendiriliyorsunuz...',
      'data_updated': 'Analiz tamamlandı ✅',
      'enter_pin': 'PIN giriniz',
      'pin_accepted': 'PIN kabul edildi, süre sıfırlandı ✅',
      'pin_incorrect': 'Yanlış PIN',
      'ok': 'TAMAM',
      'legal_intro': 'Kullanıcı, VERDICT uygulamasını kullanmaya başladığı andan itibaren aşağıdaki tüm şartları ve feragatnameleri peşinen kabul etmiş sayılır:',
      'article1_title': 'Madde 1: Veri Güvenliği ve Yerellik',
      'article1_text': "VERDICT, kullanıcıya ait giriş bilgilerini kesinlikle sunucu tarafına iletmez. Tüm veri işleme süreci kullanıcının kendi cihazındaki RAM ve yerel depolama biriminde gerçekleşir. Uygulama bir 'browser-wrapper' mantığıyla çalışarak sadece Instagram'ın sağladığı verileri okur.",
      'article2_title': 'Madde 2: Instagram Hesap Riskleri',
      'article2_text': "Instagram (Meta), üçüncü taraf araç kullanımını kısıtlama hakkını saklı tutar. Uygulamanın kullanımından doğabilecek 'eylem engelleme', 'geçici askıya alma' veya 'hesap kapatma' gibi riskler tamamen kullanıcıya aittir. VERDICT, bu tür durumlarda maddi veya manevi sorumluluk kabul etmez.",
      'article3_title': 'Madde 3: Ticari ve Hukuki Feragat',
      'article3_text': "Bu yazılım ücretsiz, 'olduğu gibi' (as-is) sunulan bir yardımcı araçtır. Yazılımın sonuçlarına dayanarak ticari veya hukuki bir işlem yapılması önerilmez. Kullanıcı, uygulamayı indirdiği ve giriş yaptığı andan itibaren geliştiriciyi tüm olası uyuşmazlıklardan muaf tuttuğunu peşinen kabul ve taahhüt eder.",
      'article4_title': 'Madde 4: Fikri Mülkiyet',
      'article4_text': "Uygulama bağımsız bir geliştirici tarafından hazırlanmıştır. Instagram, Facebook veya Meta ile doğrudan veya dolaylı bir ortaklığı bulunmamaktadır.",
      'article5_title': 'Madde 5: Mücbir Sebepler',
      'article5_text': 'Instagram altyapısında yapılacak güncellemeler sonucunda uygulamanın çalışmaz hale gelmesi durumunda geliştiricinin güncel tutma zorunluluğu bulunmamaktadır.',
      'ad_wait_message': 'Analiz tamamlandı, sonuçlar reklamdan sonra gösterilecek.'
    },
    'en': {
      'tagline': 'Professional Social Media Solutions',
      'adsense_banner': 'AD SPACE',
      'free_app_note': 'This app is designed for free use; beware of imitations.',
      'login_prompt': 'Please log in to start the analysis.',
      'welcome': 'Welcome, {username}',
      'refresh_data': 'REFRESH DATA',
      'login_with_instagram': 'LOG IN WITH INSTAGRAM',
      'fetching_data': 'Analyzing data...\nThis might take a moment.',
      'analysis_secure': 'All analysis is securely processed locally on your device.',
      'contact_info': 'For support, suggestions, and help: Instagram @grkmcomert',
      'next_analysis': 'Next analysis',
      'next_analysis_ready': 'Ready to scan.',
      'please_wait': 'Please Wait',
      'remaining_time': 'Next analysis: {time}',
      'clear_data_title': 'Reset App Data',
      'clear_data_content': 'This will wipe all local data and session cookies. Are you sure?',
      'cancel': 'CANCEL',
      'delete': 'DELETE',
      'error_title': 'Error',
      'data_fetch_error': 'Data retrieval failed: {err}\n\nTroubleshoot: Try logging out and logging back in.',
      'followers': 'Followers',
      'following': 'Following',
      'new_followers': 'New Followers',
      'non_followers': 'Don\'t Follow Back',
      'left_followers': 'Unfollowers',
      'legal_warning': 'Legal Disclaimer',
      'read_and_agree': 'I HAVE READ AND AGREE',
      'no_data': 'No data',
      'new_badge': 'NEW',
      'login_title': 'Login',
      'redirecting': 'Session verified, redirecting securely...',
      'data_updated': 'Analysis complete ✅',
      'enter_pin': 'Enter PIN',
      'pin_accepted': 'PIN accepted, timer reset ✅',
      'pin_incorrect': 'Invalid PIN',
      'ok': 'OK',
      'legal_intro': 'By using the VERDICT application, the user is deemed to have accepted all the following terms and disclaimers in advance:',
      'article1_title': 'Article 1: Data Security and Locality',
      'article1_text': "VERDICT strictly does not transmit user login information to the server side. All data processing occurs locally on the user's device RAM and local storage. The application operates on a 'browser-wrapper' principle, only reading data provided by Instagram.",
      'article2_title': 'Article 2: Instagram Account Risks',
      'article2_text': "Instagram (Meta) reserves the right to restrict the use of third-party tools. Any risks arising from the use of the application, such as 'action blocks', 'temporary suspensions', or 'account closures', are entirely the responsibility of the user. VERDICT accepts no material or moral liability in such cases.",
      'article3_title': 'Article 3: Commercial and Legal Disclaimer',
      'article3_text': "This software is a free assistant tool provided 'as-is'. It is not recommended to engage in commercial or legal transactions based on the software's results. By downloading and logging into the application, the user acknowledges and commits to exempting the developer from all potential disputes in advance.",
      'article4_title': 'Article 4: Intellectual Property',
      'article4_text': "The application has been prepared by an independent developer. It has no direct or indirect partnership with Instagram, Facebook, or Meta.",
      'article5_title': 'Article 5: Force Majeure',
      'article5_text': 'In the event that the application becomes non-functional due to updates in the Instagram infrastructure, the developer is under no obligation to provide updates.',
      'ad_wait_message': 'Analysis complete; results will be displayed after the advertisement.'
    }
  };

  String _t(String key, [Map<String, String>? args]) {
    String res = _localized[_lang]?[key] ?? key;
    if (args != null) {
      args.forEach((k, v) { res = res.replaceAll('{$k}', v); });
    }
    return res;
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final String? pref = prefs.getString('language_code');
    if (pref != null) {
      if (mounted) setState(() => _lang = pref);
      return;
    }
    try {
      final String locale = Platform.localeName;
      if (locale.toLowerCase().startsWith('tr')) {
        if (mounted) setState(() => _lang = 'tr');
      } else {
        if (mounted) setState(() => _lang = 'en');
      }
    } catch (_) {
        if (mounted) setState(() => _lang = 'en');
    }
  }

  Future<void> _setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    if (mounted) setState(() => _lang = code);
  }

  void _toggleLanguage() { _setLanguage(_lang == 'tr' ? 'en' : 'tr'); }

  @override
  void initState() {
    super.initState();
    _loadStoredData();
    _loadLanguagePreference();
    _tryAutoLogin();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserAgreement();
      _loadBannerAd();
    });
  }

  Future<void> _loadBannerAd() async {
    final bool useTestAds = _forceTestAds;
    if (_adsHidden) {
      try { _bannerAd?.dispose(); } catch (_) {}
      _bannerAd = null;
      if (mounted) setState(() { _isAdLoaded = false; _bannerAdError = null; });
      return;
    }

    final String adUnit = useTestAds
      ? (Platform.isAndroid ? 'ca-app-pub-3940256099942544/6300978111' : 'ca-app-pub-3940256099942544/2934735716')
      : (Platform.isAndroid ? 'ca-app-pub-4966303174577377/3471529345' : 'ca-app-pub-4966303174577377/3471529345');

    _currentAdUnit = adUnit;

    if (_bannerAd != null) {
      try { _bannerAd!.dispose(); } catch (_) {}
      _bannerAd = null;
      _isAdLoaded = false;
      _bannerAdError = null;
    }

    AdSize adSize = AdSize.banner;
    try {
      final int adWidth = MediaQuery.of(context).size.width.truncate();
      final AdSize? adaptive = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(adWidth);
      if (adaptive != null) adSize = adaptive;
    } catch (e) {
      if (kDebugMode) print('Adaptive size error: $e');
    }

    _bannerAd = BannerAd(
      adUnitId: adUnit,
      request: const AdRequest(),
      size: adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() { _isAdLoaded = true; _bannerAdError = null; });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (mounted) setState(() { _isAdLoaded = false; _bannerAdError = err.message; });
        },
      ),
    );

    try { await _bannerAd!.load(); } catch (e) { if (kDebugMode) print('Ad load error: $e'); }
  }

  // GÜNCELLEME: Detaylı hata mesajı döndüren metod (Aynı kaldı, sadece return type netleştirildi)
  Future<Map<String, dynamic>> _showRewardedAdWithResult() async {
    if (_isRewardedLoading) return {"status": false, "error": "Loading..."};
    setState(() { _isRewardedLoading = true; });

    final bool useTestAds = _forceTestAds;
    final String adUnit = useTestAds
      ? (Platform.isAndroid ? 'ca-app-pub-3940256099942544/5224354917' : 'ca-app-pub-3940256099942544/1712485313')
      : (Platform.isAndroid ? 'ca-app-pub-4966303174577377/1076573947' : 'ca-app-pub-4966303174577377/1076573947');

    final Completer<Map<String, dynamic>> c = Completer<Map<String, dynamic>>();
    
    // Geçici değişken
    RewardedAd? tempAd;

    RewardedAd.load(
      adUnitId: adUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          tempAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              try { ad.dispose(); } catch (_) {}
              if (!c.isCompleted) c.complete({"status": true});
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              try { ad.dispose(); } catch (_) {}
              if (!c.isCompleted) c.complete({"status": false, "error": "ShowError: ${err.message}"});
            },
          );
          try {
            ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {});
          } catch (e) {
            if (!c.isCompleted) c.complete({"status": false, "error": "Exception: $e"});
          }
        },
        onAdFailedToLoad: (LoadAdError err) {
          debugPrint("Ad failed to load: $err");
          if (!c.isCompleted) c.complete({"status": false, "error": "LoadError: ${err.message} (Code: ${err.code})"});
        },
      ),
    );

    Map<String, dynamic> result = {"status": false, "error": "Timeout"};
    try { result = await c.future.timeout(const Duration(seconds: 45)); } catch (_) {}

    try { tempAd?.dispose(); } catch (_) {}
    setState(() { _isRewardedLoading = false; });
    if (result["status"] == true) {
      try { if (mounted) setState(() { _justWatchedReward = true; }); } catch (_) {}
    }
    return result;
  }

  Future<DateTime> _getNetworkTime() async {
    try {
      final response = await http.head(Uri.parse('https://www.google.com'));
      if (response.headers['date'] != null) {
        return HttpDate.parse(response.headers['date']!).toLocal();
      }
    } catch (_) {}
    return DateTime.now();
  }

  Future<void> _startCountdownFromStoredTime() async {
    _cancelCountdown();
    final prefs = await SharedPreferences.getInstance();
    final int? lastMs = prefs.getInt('last_update_time');
    if (lastMs == null) {
      if (mounted) setState(() { _lastUpdateTimeNetwork = null; _remainingToNextAnalysis = null; });
      return;
    }

    final DateTime last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    try {
      final DateTime now = await _getNetworkTime();
      Duration remaining = const Duration(hours: 6) - now.difference(last);
      if (remaining <= Duration.zero) {
        if (mounted) setState(() { _lastUpdateTimeNetwork = last; _remainingToNextAnalysis = null; });
        return;
      }

      if (mounted) setState(() { _lastUpdateTimeNetwork = last; _remainingToNextAnalysis = remaining; });

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _remainingToNextAnalysis = (_remainingToNextAnalysis ?? Duration.zero) - const Duration(seconds: 1);
          if ((_remainingToNextAnalysis ?? Duration.zero) <= Duration.zero) {
            _remainingToNextAnalysis = null;
            _cancelCountdown();
          }
        });
      });
    } catch (_) {
      if (mounted) setState(() { _lastUpdateTimeNetwork = last; _remainingToNextAnalysis = null; });
    }
  }

  void _cancelCountdown() { try { _countdownTimer?.cancel(); } catch (_) {} _countdownTimer = null; }

  String _formatDuration(Duration d) {
    final hrs = d.inHours.remainder(100).toString().padLeft(2, '0');
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hrs:$mins:$secs';
  }

  Future<void> _showRemainingDialog() async {
    if (!mounted) return;
    final remaining = _remainingToNextAnalysis;
    if (remaining == null) {
      showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(_t('next_analysis')), content: Text(_t('next_analysis_ready')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('cancel')))]));
    } else {
      showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(_t('please_wait')), content: Text(_t('remaining_time', {'time': _formatDuration(remaining)})), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('cancel')))]));
    }
  }

  Future<void> _toggleDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { isDarkMode = !isDarkMode; prefs.setBool('is_dark_mode', isDarkMode); });
  }

  Future<void> _clearCache() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text(_t('clear_data_title')),
        content: Text(_t('clear_data_content')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) { await _logout(); if (mounted) setState(() { _loadStoredData(); }); }
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    String? cookie = prefs.getString('session_cookie');
    String? userId = prefs.getString('session_user_id');
    String? username = prefs.getString('session_username');
    String? ua = prefs.getString('session_user_agent');

    if (mounted) setState(() { isDarkMode = prefs.getBool('is_dark_mode') ?? false; });
    if (cookie != null && userId != null) {
      if (mounted) setState(() { 
        isLoggedIn = true; savedCookie = cookie; savedUserId = userId; 
        currentUsername = username ?? (_lang == 'tr' ? "Kullanıcı" : "User"); 
        savedUserAgent = ua; _loadStoredData(); 
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    bool currentDark = isDarkMode;
    await prefs.clear();
    await prefs.setBool('is_dark_mode', currentDark);
    await prefs.setBool('is_terms_accepted', true);
    try { await WebViewCookieManager().clearCookies(); } catch (_) {}
    _cancelCountdown();
    if (mounted) {
      setState(() { 
        isLoggedIn = false; currentUsername = ""; savedCookie = null; savedUserAgent = null;
        followersMap = {}; followingMap = {}; nonFollowersMap = {}; unfollowersMap = {}; newFollowersMap = {}; 
        followersCount = '?'; followingCount = '?'; nonFollowersCount = '?'; leftCount = '?'; newCount = '?'; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = isDarkMode ? const Color(0xFF000000) : const Color(0xFFF4F7F9);
    Color cardColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;
    Color primaryColor = isDarkMode ? Colors.blueAccent : Colors.blueGrey;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(alignment: Alignment.centerLeft, child: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode, color: primaryColor), onPressed: _toggleDarkMode),
                          IconButton(
                            icon: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.language, color: primaryColor), const SizedBox(width: 6), Text(_lang.toUpperCase(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))]),
                            onPressed: _toggleLanguage,
                          ),
                        ])),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('VERDICT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: primaryColor, letterSpacing: 3.0)),
                            Text(_t('tagline'), style: TextStyle(fontWeight: FontWeight.w500, fontSize: 8, color: primaryColor.withOpacity(0.6))),
                          ],
                        ),
                        Align(alignment: Alignment.centerRight, child: IconButton(icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent), onPressed: _clearCache)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryColor.withOpacity(0.1))),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (_adsHidden)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('Ads hidden for this session.', style: TextStyle(color: primaryColor.withOpacity(0.4), fontWeight: FontWeight.bold, fontSize: 10)),
                          )
                        else if (_isAdLoaded && _bannerAd != null)
                          Align(
                            alignment: Alignment.center,
                            child: LayoutBuilder(builder: (context, constraints) {
                              final double displayWidth = min(constraints.maxWidth, _bannerAd!.size.width.toDouble());
                              final double displayHeight = _bannerAd!.size.height.toDouble() * (displayWidth / _bannerAd!.size.width.toDouble());
                              return SizedBox(width: displayWidth, height: displayHeight, child: AdWidget(ad: _bannerAd!));
                            }),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(_bannerAdError != null ? 'Ad error: $_bannerAdError' : "Analiz Bekleniyor...", style: TextStyle(color: primaryColor.withOpacity(0.4), fontWeight: FontWeight.bold, fontSize: 10)),
                          )
                      ]),
                    ),
                  ],
                ),
              ),
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      _buildInfoBox(Icons.info_outline, _t('free_app_note'), primaryColor),
                      const SizedBox(height: 10),
                      if (!isLoggedIn) _buildInfoBox(Icons.lock_outline, _t('login_prompt'), Colors.redAccent)
                      else _buildInfoBox(Icons.verified_user, _t('welcome', {'username': currentUsername}), Colors.green),
                      const SizedBox(height: 25),
                      
                      if (isProcessing)
                         Container(
                           height: 250, 
                           alignment: Alignment.center,
                           child: ModernLoader(text: _t('fetching_data'), isDark: isDarkMode),
                         )
                      else 
                        _buildGrid(cardColor, textColor),
                      
                      const SizedBox(height: 30),
                      
                      if (isProcessing) 
                        const SizedBox(height: 70) 
                      else 
                        Column(children: [_buildMainButton(isDarkMode), const SizedBox(height: 8), _buildNextAnalysisInfo()]),
                      
                      const SizedBox(height: 25), 
                      Text(_t('analysis_secure'), textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: isDarkMode ? Colors.grey : Colors.blueGrey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8), 
                      Text(_t('contact_info'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87, fontSize: 11)),
                      const SizedBox(height: 30), 
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(Color cardColor, Color textColor) {
    return LayoutBuilder(builder: (context, constraints) {
      double cardWidth = (constraints.maxWidth - 20) / 2;
      return Wrap(
        spacing: 18, runSpacing: 18, alignment: WrapAlignment.center,
        children: [
          SizedBox(width: cardWidth, height: cardWidth, child: _buildBigCard('followers', followersCount, Colors.blueAccent, Icons.groups_3, cardColor, textColor)),
          SizedBox(width: cardWidth, height: cardWidth, child: _buildBigCard('following', followingCount, Colors.teal, Icons.person_add_alt_1, cardColor, textColor)),
          SizedBox(width: cardWidth, height: cardWidth, child: _buildBigCard('new_followers', newCount, Colors.green, Icons.person_add_rounded, cardColor, textColor)),
          SizedBox(width: cardWidth, height: cardWidth, child: _buildBigCard('non_followers', nonFollowersCount, Colors.orange.shade800, Icons.person_search, cardColor, textColor)),
          SizedBox(width: cardWidth, height: cardWidth, child: _buildBigCard('left_followers', leftCount, Colors.deepOrangeAccent, Icons.trending_down, cardColor, textColor)),
          SizedBox(width: cardWidth, height: cardWidth, child: _buildBigCard('legal_warning', "", Colors.blueGrey, Icons.info_outline, cardColor, textColor, isSpecial: true)),
        ],
      );
    });
  }

  Widget _buildBigCard(String titleKey, String count, Color color, IconData icon, Color cardBg, Color txtColor, {bool isSpecial = false}) {
    final String title = _t(titleKey, {'username': currentUsername});
    int badgeCount = badges[titleKey] ?? 0;
    
    return GestureDetector(
      onTapDown: (details) { if (titleKey == 'legal_warning') _startLegalHoldTimer(); },
      onTapUp: (_) { if (titleKey == 'legal_warning') _cancelLegalHoldTimer(); },
      onTapCancel: () { if (titleKey == 'legal_warning') _cancelLegalHoldTimer(); },
      onTap: () async {
        if (titleKey == 'legal_warning') { 
          showDialog(context: context, builder: (ctx) => _buildDetailedLegalDialog(ctx, isInitial: false)); 
        } else {
          Map<String, String> targetMap = followersMap;
          if (titleKey == 'following') targetMap = followingMap;
          if (titleKey == 'non_followers') targetMap = nonFollowersMap;
          if (titleKey == 'left_followers') targetMap = unfollowersMap;
          if (titleKey == 'new_followers') targetMap = newFollowersMap;
          
          await Navigator.push(context, CupertinoPageRoute(builder: (context) => DetailListPage(
            title: title, items: targetMap, color: color, isDark: isDarkMode, newItems: newItemsMap[titleKey] ?? {}, lang: _lang,
          )));

          setState(() { badges[titleKey] = 0; newItemsMap[titleKey]?.clear(); });
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 35), const SizedBox(height: 8), Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: txtColor.withOpacity(0.6)), textAlign: TextAlign.center), if(!isSpecial) Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)), if(isSpecial) const Icon(Icons.more_horiz, color: Colors.blueGrey, size: 20)]),
          ),
          if (badgeCount > 0)
            Positioned(
              right: 8, top: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                child: Text("+$badgeCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]),
      child: ElevatedButton.icon(
        onPressed: isLoggedIn ? _refreshData : () async {
          final result = await Navigator.push(context, CupertinoPageRoute(builder: (context) => InstagramApiPage(isDark: isDarkMode, lang: _lang)));
          if (result != null && result['status'] == 'success') _handleLoginSuccess(result);
        },
        icon: Icon(isLoggedIn ? Icons.refresh : Icons.fingerprint, size: 28),
        label: Text(isLoggedIn ? _t('refresh_data') : _t('login_with_instagram'), style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 70), backgroundColor: isDark ? Colors.white : Colors.blueGrey.shade900, foregroundColor: isDark ? Colors.black : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      ),
    );
  }

  Future<void> _refreshData() async {
    final prefs = await SharedPreferences.getInstance();
    final uaToUse = savedUserAgent ?? 'Instagram 315.0.0.32.109 Android (33/13; 420dpi; 1080x2400; samsung; SM-G991B; o1s; exynos2100; tr_TR; 563533633)';

    try {
      final DateTime now = await _getNetworkTime();
      final int? lastMs = prefs.getInt('last_update_time');
      if (lastMs != null) {
        final DateTime last = DateTime.fromMillisecondsSinceEpoch(lastMs);
        final Duration wait = const Duration(hours: 6) - now.difference(last);
        if (wait > Duration.zero) {
          if (mounted) {
            final bool? wantWatch = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: Text(_t('please_wait')), content: Text(_t('remaining_time', {'time': _formatDuration(wait)})),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('cancel'))),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_lang == 'tr' ? 'Reklam izle ve başlat' : 'Watch ad and start')),
              ],
            ));
            if (wantWatch != true) return;
            
            // GÜNCELLEME: BURADA HATA GİZLENMİYOR, SNACKBAR AÇILIYOR
            final adResult = await _showRewardedAdWithResult();
            if (adResult["status"] == false) {
              if(mounted) {
                String errorMsg = _lang == 'tr' ? "Reklam Yüklenemedi: " : "Ad failed to load: ";
                // Kullanıcının neden reklam görmediğini gösteren kısım burası
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("$errorMsg ${adResult['error']}"), 
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ));
              }
              // Hata olsa da devam etmiyoruz, çünkü izlemedi. (Veya istersen return'ü kaldırıp devam ettirirsin)
              return;
            }
          } else return;
        }
      }
    } catch (_) {}

    setState(() => isProcessing = true);
    
    try {
      Map<String, dynamic>? info = await _fetchUserInfoRaw(savedUserId!, savedCookie!, uaToUse);
      int tFollowers = info?['follower_count'] ?? 0;
      int tFollowing = info?['following_count'] ?? 0;

      Map<String, String> nFollowers = {};
      await _fetchPagedData(userId: savedUserId!, cookie: savedCookie!, ua: uaToUse, type: 'followers', totalExpected: tFollowers, targetMap: nFollowers);

      Map<String, String> nFollowing = {};
      await _fetchPagedData(userId: savedUserId!, cookie: savedCookie!, ua: uaToUse, type: 'following', totalExpected: tFollowing, targetMap: nFollowing);
      
      if (nFollowers.isNotEmpty || nFollowing.isNotEmpty) {
          if (!_adsHidden && !_justWatchedReward) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_t('ad_wait_message')), 
                  duration: const Duration(seconds: 4), 
                  backgroundColor: Colors.blueGrey.shade900,
                )
              );
            }
            
            await Future.delayed(const Duration(seconds: 2));

            // GÜNCELLEME: Analiz sonu reklam hatası kontrolü - Gizlemiyoruz
            final adResult = await _showRewardedAdWithResult();
            if (adResult["status"] == false) {
              if(mounted) {
                String errorMsg = _lang == 'tr' ? "Analiz Sonu Reklam Hatası: " : "Ad Error: ";
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("$errorMsg ${adResult['error']}"), 
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ));
              }
            }
          }

          await _processData(nFollowers, nFollowing);

          if (_justWatchedReward) setState(() => _justWatchedReward = false);
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('data_updated')), backgroundColor: Colors.green));
      }
    } catch (e) { 
        if(mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(_t('error_title')), content: Text(_t('data_fetch_error', {'err': e.toString()}))));
    } finally { 
        if (mounted) setState(() => isProcessing = false); 
    }
  }

  Future<Map<String, dynamic>?> _fetchUserInfoRaw(String userId, String cookie, String ua) async {
    final response = await http.get(Uri.parse("https://i.instagram.com/api/v1/users/$userId/info/"), headers: {'Cookie': cookie, 'X-IG-App-ID': '936619743392459', 'User-Agent': ua});
    return response.statusCode == 200 ? jsonDecode(response.body)['user'] : null;
  }

  Future<void> _fetchPagedData({required String userId, required String cookie, required String ua, required String type, required int totalExpected, required Map<String, String> targetMap}) async {
    String endpoint = type == 'followers' ? 'friendships/$userId/followers' : 'friendships/$userId/following';
    String? nextMaxId;
    bool hasNext = true;

    while (hasNext) {
       String url = "https://i.instagram.com/api/v1/$endpoint/?count=50"; 
       if (nextMaxId != null) url += "&max_id=$nextMaxId";

       final response = await http.get(Uri.parse(url), headers: {'Cookie': cookie, 'X-IG-App-ID': '936619743392459', 'User-Agent': ua});

       if (response.statusCode == 200) {
         final data = jsonDecode(response.body);
         for (var u in data['users']) { targetMap[u['username'].toString()] = u['profile_pic_url'].toString(); }
         nextMaxId = data['next_max_id'];
         hasNext = nextMaxId != null && nextMaxId.isNotEmpty;
         
         await Future.delayed(const Duration(milliseconds: 500));
       } else {
         hasNext = false;
       }
    }
  }

  void _handleLoginSuccess(dynamic result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_cookie', result['cookie']);
    await prefs.setString('session_user_id', result['user_id']);
    await prefs.setString('session_username', result['username']);
    await prefs.setString('session_user_agent', result['user_agent']);
    if (mounted) { 
      setState(() { isLoggedIn = true; savedCookie = result['cookie']; savedUserId = result['user_id']; currentUsername = result['username']; savedUserAgent = result['user_agent']; }); 
      _refreshData();
    }
  }

  Future<void> _processData(Map<String, String> nFollowers, Map<String, String> nFollowing) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> oldFollowers = _safeMapCast(jsonDecode(prefs.getString('followers_map') ?? '{}'));
    Map<String, String> oldFollowing = _safeMapCast(jsonDecode(prefs.getString('following_map') ?? '{}'));
    Map<String, String> storedUnfollowers = _safeMapCast(jsonDecode(prefs.getString('unfollowers_map') ?? '{}'));
    
    Map<String, String> newFollowers = {};
    bool isFirstRun = oldFollowers.isEmpty;
    badges = {'followers': 0, 'following': 0, 'new_followers': 0, 'non_followers': 0, 'left_followers': 0};
    newItemsMap = {'followers': {}, 'following': {}, 'new_followers': {}, 'non_followers': {}, 'left_followers': {}};

    oldFollowers.forEach((user, img) { 
      if (!nFollowers.containsKey(user)) {
        if (!storedUnfollowers.containsKey(user)) { badges['left_followers'] = (badges['left_followers'] ?? 0) + 1; newItemsMap['left_followers']!.add(user); }
        storedUnfollowers[user] = img; 
      }
    });

    nFollowers.forEach((user, img) { 
      if (!oldFollowers.containsKey(user) && !isFirstRun) { newFollowers[user] = img; badges['new_followers'] = (badges['new_followers'] ?? 0) + 1; newItemsMap['new_followers']!.add(user); newItemsMap['followers']!.add(user); }
    });
    badges['followers'] = isFirstRun ? nFollowers.length : newItemsMap['followers']!.length;

    nFollowing.forEach((user, img) { if(!oldFollowing.containsKey(user)) { badges['following'] = (badges['following'] ?? 0) + 1; newItemsMap['following']!.add(user); } });

    Map<String, String> curNon = {};
    nFollowing.forEach((u, img) { if (!nFollowers.containsKey(u)) curNon[u] = img; });
    Map<String, String> oldNon = {};
    oldFollowing.forEach((u, img) { if (!oldFollowers.containsKey(u)) oldNon[u] = img; });

    curNon.forEach((user, img) { if (!oldNon.containsKey(user)) { badges['non_followers'] = (badges['non_followers'] ?? 0) + 1; newItemsMap['non_followers']!.add(user); } });

    await prefs.setString('followers_map', jsonEncode(nFollowers));
    await prefs.setString('following_map', jsonEncode(nFollowing));
    await prefs.setString('unfollowers_map', jsonEncode(storedUnfollowers));
    await prefs.setString('new_followers_map', jsonEncode(newFollowers));
    
    final realNow = await _getNetworkTime();
    await prefs.setInt('last_update_time', realNow.millisecondsSinceEpoch);
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        followersMap = _safeMapCast(jsonDecode(prefs.getString('followers_map') ?? '{}'));
        followingMap = _safeMapCast(jsonDecode(prefs.getString('following_map') ?? '{}'));
        unfollowersMap = _safeMapCast(jsonDecode(prefs.getString('unfollowers_map') ?? '{}'));
        newFollowersMap = _safeMapCast(jsonDecode(prefs.getString('new_followers_map') ?? '{}'));
        nonFollowersMap = {}; followingMap.forEach((u, img) { if (!followersMap.containsKey(u)) nonFollowersMap[u] = img; });
        followersCount = isLoggedIn ? followersMap.length.toString() : '?';
        followingCount = isLoggedIn ? followingMap.length.toString() : '?';
        nonFollowersCount = isLoggedIn ? nonFollowersMap.length.toString() : '?';
        leftCount = isLoggedIn ? unfollowersMap.length.toString() : '?';
        newCount = isLoggedIn ? newFollowersMap.length.toString() : '?';
      });
    }
    await _startCountdownFromStoredTime();
  }

  Map<String, String> _safeMapCast(dynamic input) { Map<String, String> output = {}; if (input is Map) input.forEach((k, v) => output[k.toString()] = v.toString()); return output; }

  Widget _buildInfoBox(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.1))),
      child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)))]),
    );
  }

  Widget _buildNextAnalysisInfo() {
    if (!isLoggedIn) return const SizedBox.shrink();
    final remaining = _remainingToNextAnalysis;
    return GestureDetector(onTap: _showRemainingDialog, child: Text(remaining == null ? '${_t('next_analysis')}: ${_t('next_analysis_ready')}' : '${_t('next_analysis')}: ${_formatDuration(remaining)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)));
  }

  Future<void> _checkUserAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('is_terms_accepted') ?? false)) {
      if (mounted) showDialog(context: context, barrierDismissible: false, builder: (ctx) => _buildDetailedLegalDialog(ctx, isInitial: true, prefs: prefs));
    }
  }

  @override
  void dispose() { _cancelCountdown(); _cancelLegalHoldTimer(); _bannerAd?.dispose(); super.dispose(); }

  void _startLegalHoldTimer() { _cancelLegalHoldTimer(); _legalHoldTimer = Timer(const Duration(seconds: 5), () => _promptSecretPin()); }
  void _cancelLegalHoldTimer() { _legalHoldTimer?.cancel(); _legalHoldTimer = null; }

  Future<void> _promptSecretPin() async {
    final TextEditingController pCtrl = TextEditingController();
    final entered = await showDialog<String?>(context: context, builder: (ctx) => AlertDialog(title: Text(_t('legal_warning')), content: TextField(controller: pCtrl, obscureText: true, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: _t('enter_pin'))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('cancel'))), TextButton(onPressed: () => Navigator.pop(ctx, pCtrl.text), child: Text(_t('ok')))]));
    if (entered != null) _handlePinEntry(entered.trim());
  }

  Future<void> _handlePinEntry(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    if (pin == '3333') {
      await prefs.remove('last_update_time');
      _startCountdownFromStoredTime();
      _bannerAd?.dispose();
      if (mounted) setState(() { _adsHidden = true; _bannerAd = null; _isAdLoaded = false; });
    }
  }

  Widget _buildDetailedLegalDialog(BuildContext context, {required bool isInitial, SharedPreferences? prefs}) {
    return AlertDialog(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Icon(Icons.info_outline, color: Colors.blueAccent), const SizedBox(width: 10), Text(_t('legal_warning'))]),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_t('legal_intro'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 15), _legalSection('article1_title', 'article1_text'), _legalSection('article2_title', 'article2_text'), _legalSection('article3_title', 'article3_text'), _legalSection('article4_title', 'article4_text'), _legalSection('article5_title', 'article5_text')])),
      actions: [isInitial ? SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { prefs?.setBool('is_terms_accepted', true); Navigator.pop(context); }, child: Text(_t('read_and_agree')))) : TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('cancel')))],
    );
  }

  Widget _legalSection(String titleKey, String contentKey) {
    return Padding(padding: const EdgeInsets.only(bottom: 15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_t(titleKey), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13)), const SizedBox(height: 4), Text(_t(contentKey), style: const TextStyle(fontSize: 11, height: 1.5))]));
  }
}

class DetailListPage extends StatelessWidget {
  final String title; final Map<String, String> items; final Color color; final bool isDark; final Set<String> newItems; final String lang;
  const DetailListPage({super.key, required this.title, required this.items, required this.color, required this.isDark, required this.newItems, required this.lang});
  @override
  Widget build(BuildContext context) {
    List<String> names = items.keys.toList();
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white, appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: isDark ? const Color(0xFF121212) : Colors.white, foregroundColor: isDark ? Colors.white : Colors.black),
      body: items.isEmpty ? Center(child: Text(lang == 'tr' ? 'Veri yok' : 'No data')) : ListView.builder(itemCount: names.length, itemBuilder: (ctx, i) {
        bool isNew = newItems.contains(names[i]);
        return ListTile(
          onTap: () async { final Uri url = Uri.parse('https://www.instagram.com/${names[i]}/'); if (!await launchUrl(url, mode: LaunchMode.externalApplication)) { Clipboard.setData(ClipboardData(text: names[i])); } },
          leading: CircleAvatar(backgroundImage: NetworkImage(items[names[i]] ?? "")), 
          title: Row(children: [Text(names[i], style: const TextStyle(fontWeight: FontWeight.bold)), if (isNew) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text(lang == 'tr' ? 'YENİ' : 'NEW', style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)))]]),
          trailing: const Icon(Icons.open_in_new, size: 18),
        );
      })
    );
  }
}

class InstagramApiPage extends StatefulWidget {
  final bool isDark; final String lang;
  const InstagramApiPage({super.key, required this.isDark, required this.lang});
  @override
  State<InstagramApiPage> createState() => _InstagramApiPageState();
}

class _InstagramApiPageState extends State<InstagramApiPage> {
  late final WebViewController _controller;
  static const platform = MethodChannel('com.grkmcomert.unfollowerscurrent/cookie');
  bool isScanning = false;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..setNavigationDelegate(NavigationDelegate(onUrlChange: (change) {
      final url = change.url ?? "";
      if (url.contains("instagram.com/") && !url.contains("login") && !url.contains("accounts/")) { if (!isScanning) _startSafeApiProcess(); }
    }))..loadRequest(Uri.parse('https://www.instagram.com/accounts/login/'));
  }
  Future<void> _startSafeApiProcess() async {
    if (!mounted) return;
    setState(() => isScanning = true);
    await Future.delayed(const Duration(seconds: 2));
    try {
      final String? cookieString = await platform.invokeMethod('getCookies', {'url': "https://www.instagram.com"});
      if (cookieString == null || !cookieString.contains("ds_user_id")) { setState(() => isScanning = false); return; }
      String? dsUserId, username;
      cookieString.split(';').forEach((part) { if (part.trim().startsWith('ds_user_id=')) dsUserId = part.split('=')[1]; });
      String userAgent = (await _controller.runJavaScriptReturningResult('navigator.userAgent') as String).replaceAll('"', '');
      try {
        final infoResponse = await http.get(Uri.parse("https://i.instagram.com/api/v1/users/$dsUserId/info/"), headers: {'Cookie': cookieString, 'X-IG-App-ID': '936619743392459', 'User-Agent': userAgent});
        if (infoResponse.statusCode == 200) username = jsonDecode(infoResponse.body)['user']['username'];
      } catch (_) {}
      if (mounted) Navigator.pop(context, {"status": "success", "cookie": cookieString, "user_id": dsUserId, "username": username ?? (widget.lang == 'tr' ? "Kullanıcı" : "User"), "user_agent": userAgent});
    } catch (e) { if (mounted) setState(() => isScanning = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDark ? Colors.black : Colors.white,
      appBar: AppBar(title: Text(widget.lang == 'tr' ? 'Giriş Yap' : 'Login'), backgroundColor: widget.isDark ? const Color(0xFF121212) : Colors.white, foregroundColor: widget.isDark ? Colors.white : Colors.black),
      body: isScanning ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(widget.lang == 'tr' ? 'Oturum doğrulandı, yönlendiriliyorsunuz...' : 'Session verified, redirecting...')])) : WebViewWidget(controller: _controller)
    );
  }
}