YAWMY Android v1.1.0 — offline-first build

1) Create a NEW GitHub repository (do not use the old repository).
2) Upload the full contents of this project, including .github/workflows.
3) Open Actions and run “Build YAWMY APK”.
4) The workflow downloads all offline content at build time, validates it, then builds app-debug.apk.
5) Download artifact “YAWMY-debug-apk-v1.1.0”.

Offline bundle includes the 604-page Hafs/KFQC Mushaf, full Bukhari/Muslim, azkar/duas, prophet stories/quizzes, Tafseer Muyassar, 99 Names, Quran indexes and local adhan audio.

The final compressed APK size is printed by GitHub Actions; it should be judged from the real resource payload rather than artificial padding.
