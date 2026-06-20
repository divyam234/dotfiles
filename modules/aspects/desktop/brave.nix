{ den, ... }:
{
  den.aspects.brave = {
    nixos = {
      environment.etc."brave/policies/managed/10-debloat.json".text = builtins.toJSON {
        BraveRewardsDisabled = true;
        BraveWalletDisabled = true;
        BraveVPNDisabled = true;
        BraveAIChatEnabled = false;
        BraveNewsDisabled = true;
        BraveTalkDisabled = true;
        BravePlaylistEnabled = false;
        BraveSpeedreaderEnabled = false;
        BraveWaybackMachineEnabled = false;
        TorDisabled = true;
        BraveShieldsDisabledForUrls = [
          "https://*"
          "http://*"
        ];

        # Disable Brave telemetry and product-discovery pings.
        BraveP3AEnabled = false;
        BraveStatsPingEnabled = false;
        BraveWebDiscoveryEnabled = false;
        MetricsReportingEnabled = false;
        SafeBrowsingExtendedReportingEnabled = false;
        UrlKeyedAnonymizedDataCollectionEnabled = false;
        UserFeedbackAllowed = false;
        PromotionsEnabled = false;
        PromptForDownloadLocation = false;

        # Keep the browser quiet and remove the sponsored new-tab surface.
        BackgroundModeEnabled = false;
        DefaultBrowserSettingEnabled = false;
        NewTabPageLocation = "about:blank";
        ShowHomeButton = false;

        # Preserve useful privacy and graphics functionality.
        HardwareAccelerationModeEnabled = true;
        PasswordManagerEnabled = false;
        AutofillAddressEnabled = false;
        AutofillCreditCardEnabled = false;
      };
    };

    homeManager =
      { pkgs, ... }:
      {
        programs.chromium = {
          enable = true;
          package = pkgs.brave;
          commandLineArgs = [
            "--ignore-gpu-blocklist"
            "--enable-features=AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL"
            "--disable-features=AutofillSavePaymentMethods"
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
