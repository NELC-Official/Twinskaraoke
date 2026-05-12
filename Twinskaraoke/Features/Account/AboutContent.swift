import Foundation

enum AboutContent {
  static let intro = """
    Neuro & Evil Karaoke Web Player is a fan-made project created by Soul. \
    It is a community platform dedicated to preserving and enjoying songs covered \
    by Neuro and Evil, along with related fan content.
    """

  static let unofficialNotice =
    "This website is unofficial and is not affiliated with any official Vedal AI entities."

  static let features = """
    KARAOKE SONGS
    • Listen to available songs from the collection
    • Create playlists with or without logging in
    • Select custom cover art for playlists
    • Download songs for personal, non-commercial use
    • Create public playlists that other users can view and listen to
    ART GALLERY
    • Fan-created artwork of Neuro and Evil
    • All artworks displayed are used with explicit permission from the respective artists
    • Artwork may be displayed for viewing and fan appreciation only. Artwork is not to be reused, redistributed, or commercially exploited without the artist's permission
    • Artist credits are provided where applicable
    • Updated with a revamped tagging system featuring over 3,000 tags for more granular artwork search and discovery
    VIDEO GALLERY
    • A gallery of karaoke clips from karaoke streams
    • All videos are edited and uploaded by FlashFire8
    • Channel: youtube.com/@neurokaraoke
    SOUNDBITES
    • A collection of soundbites featuring Neuro and Evil captured from streams
    • Created and edited by Rachinova and CJ
    KARAOKE QUIZ
    Test your knowledge of Neuro and Evil karaoke covers:
    • Daily Bandle Challenge — A new song challenge every day. Daily, weekly, monthly, and all-time leaderboards
    • Practice Mode — Customizable round and difficulty settings
    • Multiplayer Mode — Real-time quiz battles with friends
    • Battle Royale — Last neuron standing! Players are eliminated each round with escalating audio effects and shrinking timers
    LISTEN ALONG
    • Establish rooms with friends and listen to peak music together in real time
    • Synchronized playback so everyone hears the same song at the same time
    • Built-in chat to discuss songs and vibe with the community
    RADIO STATION — NEURO 21 STATION
    A dedicated radio broadcasting all Neuro and Evil karaoke covers 24/7. \
    Powered by AzuraCast, this is an actual internet radio station that streams continuously.
    OFFLINE DOWNLOADS & PWA
    • The website is a Progressive Web App (PWA) with offline capabilities
    • Download songs to your browser storage and listen without an internet connection
    • The site itself is accessible offline after your first visit with internet
    NEURO & EVIL QUOTES
    • Memorable quotes from our esteemed AI overlords
    • Submit your favorite Neuro and Evil quotes — submitters are credited
    • Quotes are managed by Promote
    REAL-TIME CHAT
    • Chat with other users in Listen Along rooms and during multiplayer/battle royale quiz games
    • Moderated by NeuroCop and EvilCop — AI-powered moderator bots roleplaying as Neuro and Evil to keep things fun and safe
    BADGE & LEVELING SYSTEM
    • Collect badges by completing various activities and achievements
    • Earn experience points (XP) through listening, playing quizzes, upvoting, and more to level up your profile
    • Badges come in four rarities: Common, Rare, Epic, and Legendary
    • Badge art by liquain (x.com/liquain_) • Badge art editing by Emuz (x.com/possiblyemuz)
    CURRENCIES — Neuro Coin | Evil Coin | Twins Coin
    • Three in-site currencies earned through activities like listening, playing the daily challenge, quiz games, upvoting, and leveling up
    • Each coin can only be earned on its respective domain (Neuro Coin on neurokaraoke.com, Evil Coin on evilkaraoke.com, Twins Coin on twinskaraoke.com)
    • Spend coins to expand your playlist limit or upload song limit
    • Coming soon!
    KARAOKE APP
    The Neuro & Evil Karaoke App is a community project created and maintained by Aferil. \
    Desktop (Windows), Linux, and macOS versions are packaged as standalone apps. \
    The Android version is available as an APK.
    NEURO-SAMA'S SWARM CANVAS
    A community canvas project connected to the website. Dedicated to:
    • Creating pixel art of Neuro-sama and Evil Neuro
    • Converting pixel art into canvas-compatible formats
    • Coordinating placement of artwork on pixel-based game canvases
    • Login sessions with pxls.space now persist across page reloads (requires third-party cookies; iOS not supported)
    • Contact _laku. on Discord or any Swarm Canvas council members for assistance
    """

  static let language = """
    The site supports three languages: English, Japanese, and Chinese.
    Hover over or click the language icon in the navigation bar to switch languages.
    """

  static let contact = """
    For inquiries, credit corrections, or copyright take-down requests, please contact:
    @soul1419 on Discord
    """

  static let privacy = """
    PRIVACY
    We collect only minimal data required for functionality.
    Guest users:
    • Anonymous guest ID stored in browser local storage
    Logged-in users:
    • Discord user ID and avatar
    Playlists & uploads:
    • Stored securely
    • User-uploaded songs remain private
    We do not collect emails, real names, or sensitive personal data.
    On this device, Twinskaraoke stores your sign-in token, recently played \
    playlists, and downloaded audio. We do not sell or share your listening \
    data with third parties.
    Anonymous guest identifiers are sent to api.neurokaraoke.com when you browse \
    the catalog. When you sign in, your account token is sent to the same service \
    to fetch your favorites and personal settings. Audio cover art and song files \
    are streamed from neurokaraoke.com. Live radio metadata comes from \
    radio.twinskaraoke.com.
    """

  static let terms = """
    TERMS OF SERVICE
    By using this website, you agree to the following:
    FAN-MADE PROJECT DISCLAIMER
    This website is a non-commercial, fan-made project and is not officially \
    affiliated with Neuro or Evil.
    PERSONAL & NON-COMMERCIAL USE ONLY
    All content is provided for personal enjoyment only. Commercial use is prohibited.
    USER RESPONSIBILITY
    Users are solely responsible for any content they upload.
    PLAYLIST RETENTION POLICY
    Guest playlists may be deleted after 30 days of inactivity. Logged-in users \
    retain playlists across devices.
    PUBLIC VISIBILITY
    Public playlists may be viewed and listened to by other users.
    NO LIABILITY
    The website is provided "as-is". We are not responsible for data loss, \
    service availability, or third-party claims.
    COPYRIGHT COMPLIANCE
    We comply with DMCA and applicable international copyright regulations.
    """
}
