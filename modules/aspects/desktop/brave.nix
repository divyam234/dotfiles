{ inputs, den, ... }:
{

  den.aspects.brave = {
    nixos = {
      environment.etc."brave/policies/managed/10-debloat.json".text = builtins.toJSON {
        BraveShieldsDisabledForUrls = [
          "https://*"
          "http://*"
        ];
        PromotionsEnabled = false;
        PromptForDownloadLocation = false;
        BackgroundModeEnabled = false;
        ShowHomeButton = false;
        HardwareAccelerationModeEnabled = true;
        RestoreOnStartup = 1;
        HideCrashRestoreBubble = true;

        # Brave product features and promotions.
        BraveAIChatEnabled = false;
        BraveNewsDisabled = true;
        BravePlaylistEnabled = false;
        BraveRewardsDisabled = true;
        BraveSpeedreaderEnabled = false;
        BraveTalkDisabled = true;
        BraveVPNDisabled = true;
        BraveWalletDisabled = true;
        BraveWaybackMachineEnabled = false;
        TorDisabled = true;

        # Brave telemetry, analytics, discovery, and feedback.
        BraveP3AEnabled = false;
        BraveStatsPingEnabled = false;
        BraveWebDiscoveryEnabled = false;
        BrowserNetworkTimeQueriesEnabled = false;
        FeedbackSurveysEnabled = false;
        MetricsReportingEnabled = false;
        UrlKeyedAnonymizedDataCollectionEnabled = false;
        UserFeedbackAllowed = false;

        # Brave privacy protections.
        BraveDebouncingEnabled = true;
        BraveDeAmpEnabled = true;
        BraveGlobalPrivacyControlEnabled = true;
        BraveReduceLanguageEnabled = true;
        BraveTrackingQueryParametersFilteringEnabled = true;
        DefaultBraveAdblockSetting = 2;
        DefaultBraveFingerprintingV2Setting = 3;
        DefaultBraveHttpsUpgradeSetting = 2;
        DefaultBraveReferrersSetting = 2;
        DefaultBraveRemember1PStorageSetting = 1;

        # Sync/sign-in.
        BrowserSignin = 1;
        SyncDisabled = false;

        # Password manager, passkeys, autofill, and import surfaces.
        AutofillAddressEnabled = false;
        AutofillCreditCardEnabled = false;
        AutofillPredictionSettings = 2;
        ImportAutofillFormData = false;
        ImportSavedPasswords = false;
        PasswordLeakDetectionEnabled = false;
        PasswordManagerEnabled = false;
        PasswordManagerPasskeysEnabled = false;
        PasswordSharingEnabled = false;

        # Search, suggestions, prediction, field trials, and background lookups.
        AlternateErrorPagesEnabled = false;
        ChromeVariations = 1;
        DomainReliabilityAllowed = false;
        NetworkPredictionOptions = 2;
        SearchSuggestEnabled = false;

        # Keep Standard Safe Browsing, but disable extra reporting/scanning paths.
        DisableSafeBrowsingProceedAnyway = true;
        SafeBrowsingDeepScanningEnabled = false;
        SafeBrowsingExtendedReportingEnabled = false;
        SafeBrowsingProtectionLevel = 1;
        SafeBrowsingProxiedRealTimeChecksAllowed = false;
        SafeBrowsingSurveysEnabled = false;

        # HTTPS, DNS, and WebRTC leakage controls.
        EncryptedClientHelloEnabled = true;
        HttpsOnlyMode = "force_enabled";
        HttpsUpgradesEnabled = true;
        WebRtcEventLogCollectionAllowed = false;
        WebRtcIPHandling = "disable_non_proxied_udp";
        WebRtcTextLogCollectionAllowed = false;

        # Google/Chromium AI integrations exposed by the current Brave template.
        AIModeSettings = 1;
        BuiltInAIAPIsEnabled = false;
        CreateThemesSettings = 2;
        DevToolsGenAiSettings = 2;
        GeminiSettings = 1;
        GenAILocalFoundationalModelSettings = 1;
        HelpMeWriteSettings = 2;
        HistorySearchSettings = 2;
        SearchContentSharingSettings = 1;
        TabCompareSettings = 2;

        # UI/features commonly considered clutter or promotion.
        BrowserLabsEnabled = false;
        DefaultBrowserSettingEnabled = false;
        DesktopSharingHubEnabled = false;
        EnableMediaRouter = false;
        GoogleSearchSidePanelEnabled = false;
        HistoryClustersVisible = false;
        NTPCardsVisible = false;
        NTPMiddleSlotAnnouncementVisible = false;
        NTPOutlookCardVisible = false;
        NTPSharepointCardVisible = false;
        PrivacySandboxPromptEnabled = false;
        ShoppingListEnabled = false;
        ShowFullUrlsInAddressBar = true;
        SideSearchEnabled = false;

        # Site permission defaults. Content setting value 2 generally means block.

        DefaultClipboardSetting = 2;
        DefaultFileSystemReadGuardSetting = 2;
        DefaultFileSystemWriteGuardSetting = 2;
        DefaultGeolocationSetting = 2;
        DefaultIdleDetectionSetting = 2;
        DefaultInsecureContentSetting = 2;
        DefaultLocalFontsSetting = 2;
        DefaultNotificationsSetting = 2;
        DefaultPopupsSetting = 2;
        DefaultSensorsSetting = 2;
        DefaultSerialGuardSetting = 2;
        DefaultWebBluetoothGuardSetting = 2;
        DefaultWebHidGuardSetting = 2;
        DefaultWebUsbGuardSetting = 2;
        DefaultWindowManagementSetting = 2;

        # Disable online spellcheck/translate services.
        SpellCheckServiceEnabled = false;
        TranslateEnabled = false;
      };
    };

    homeManager =
      {
        pkgs,
        ...
      }:
      {
        programs.chromium = {
          enable = true;
          package = pkgs.brave;
          commandLineArgs = [
            "--password-store=gnome-libsecret"
          ];
        };

        xdg.mimeApps = {
          enable = true;
          defaultApplications = {
            "text/html" = [ "brave-browser.desktop" ];
            "application/xhtml+xml" = [ "brave-browser.desktop" ];
            "x-scheme-handler/http" = [ "brave-browser.desktop" ];
            "x-scheme-handler/https" = [ "brave-browser.desktop" ];
          };
        };
      };
  };
}
