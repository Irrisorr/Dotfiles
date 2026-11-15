// lyrics-settings: keeps Spicy Lyrics' settings in the dotfiles. Spicy Lyrics
// stores them only in Spotify's localStorage ("SL:settings"); `spice lyrics`
// reads them from disk into SAVED below (a page can't write files). A Spotify
// that hasn't had them yet (fresh install, new machine) gets SAVED once, at its
// first start; "Restore saved Spicy Lyrics settings" in the profile menu any time.
(function lyricsSettings() {
  const KEY = "SL:settings";
  const DONE = "lyrics-settings:restored";
  // spice writes the saved settings between these two lines
  const SAVED = {
    "lyricsSize": 100,
    "rendererVisualStyle": "spring",
    "minimalLyricsMode": false,
    "syllableMerge": "off",
    "romanizationDisplay": "underLine",
    "lineHoverBackground": true,
    "duetLinePadding": true,
    "creditsFollowLastLine": false,
    "backgroundStyle": "none",
    "showNpvDynamicBg": false,
    "smoothScrolling": true,
    "staticAutoScroll": "basic",
    "scrollLeadEnabled": true,
    "timelineOutsideMediaContent": true,
    "releaseYearPosition": "right",
    "lockedMediaBox": true,
    "showNoLyricsNotice": true,
    "showQueueWhenNoLyrics": true,
    "showVolumeSlider": true,
    "motionArtwork": false,
    "motionArtworkPriority": "motion",
    "disableNpvLyrics": false,
    "removeSpotifyLyricsButton": true,
    "popupLyricsAllowed": true,
    "skipSpicyFont": false,
    "animationFpsCapEnabled": true,
    "animationFpsCap": 20,
    "experiment:playerBelowCover": true,
    "experiment:largerCinemaLyrics": false,
    "viewControlsPosition": "Top",
    "experiment:canvasImmersive": false,
    "experiment:npvCanvasBackground": false,
    "experiment:refinedBackground": false,
    "experiment:musicReactiveBackground": true,
    "experiment:newProgressBarStyling": true,
    "experiment:popupDock": true,
    "experiment:scrubPreview": true,
    "experiment:portraitFullscreen": true,
    "experiment:nextUpCard": true,
    "experiment:groupedViewControls": true,
    "experiment:refinedCredits": true,
    "experiment:keepOverlappingLines": true,
    "experiment:springLineSpacing": true,
    "experiment:lyricsSkeleton": true,
    "hideNpvLyricsWhenUnavailable": true
  };
  // end of saved settings

  const { Menu, showNotification } = Spicetify;
  if (!Menu || !showNotification) return setTimeout(lyricsSettings, 300);

  const restore = () => {
    localStorage.setItem(KEY, JSON.stringify(SAVED));
    localStorage.setItem(DONE, "1");
    location.reload();
  };

  if (SAVED && !localStorage.getItem(DONE)) {
    if (localStorage.getItem(KEY) !== JSON.stringify(SAVED)) return restore();
    localStorage.setItem(DONE, "1");
  }

  new Menu.Item("Restore saved Spicy Lyrics settings", false, () => {
    if (!SAVED) return showNotification("Nothing saved yet: run spice lyrics in a terminal", true);
    restore();
  }).register();
})();
