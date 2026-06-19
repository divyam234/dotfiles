{ den, ... }:
{
  den.aspects.brave = {
    nixos = {
      environment.etc."brave/policies/managed/10-debloat.json".text = builtins.toJSON {
        # Remove Brave's crypto, ad-rewards, VPN, AI and promotional surfaces.
        BraveRewardsDisabled = 1;
        BraveWalletDisabled = 1;
        BraveVPNDisabled = 1;
        BraveAIChatEnabled = 0;
        BraveNewsDisabled = 1;
        BraveTalkDisabled = true;
        BravePlaylistEnabled = 0;
        BraveSpeedreaderEnabled = 0;
        BraveWaybackMachineEnabled = 0;
        TorDisabled = 1;

        # Disable Brave telemetry and product-discovery pings.
        BraveP3AEnabled = false;
        BraveStatsPingEnabled = 0;
        BraveWebDiscoveryEnabled = 0;
        MetricsReportingEnabled = false;
        SafeBrowsingExtendedReportingEnabled = false;
        UrlKeyedAnonymizedDataCollectionEnabled = false;
        UserFeedbackAllowed = false;

        # Keep the browser quiet and remove the sponsored new-tab surface.
        BackgroundModeEnabled = false;
        DefaultBrowserSettingEnabled = false;
        PromotionalTabsEnabled = false;
        NewTabPageLocation = "about:blank";
        HomepageLocation = "about:blank";
        ShowHomeButton = false;

        # Preserve useful privacy and graphics functionality.
        HardwareAccelerationModeEnabled = true;
        PasswordManagerEnabled = true;
      };
    };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.brave ];

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
