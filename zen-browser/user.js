// ─── Tabs behaviour ──────────────────────────────────────────────────────────
user_pref("browser.tabs.insertAfterCurrent", false);          // new tab goes to the end, not right after current
user_pref("browser.tabs.insertRelatedAfterCurrent", false);   // child tabs (opened from a link) also go to the end
user_pref("browser.tabs.loadInBackground", false);            // switch to a tab opened from a link immediately
user_pref("browser.link.open_newwindow", 3);                  // open new windows as tabs instead

// ─── Startup & downloads ─────────────────────────────────────────────────────
user_pref("browser.startup.page", 3);                         // restore previous session on launch
user_pref("browser.download.useDownloadDir", false);          // always ask where to save downloads

// ─── Fonts ───────────────────────────────────────────────────────────────────
user_pref("font.name.serif.x-cyrillic", "JetBrainsMono Nerd Font");
user_pref("font.name.serif.x-western", "JetBrainsMono Nerd Font");
user_pref("font.size.variable.x-cyrillic", 14);

// ─── Zen UI / layout ─────────────────────────────────────────────────────────
user_pref("zen.view.show-newtab-button-top", false);          // hide the top "new tab" button
user_pref("zen.view.sidebar-expanded", true);                 // sidebar expanded by default
user_pref("zen.view.use-single-toolbar", false);              // keep separate toolbars
user_pref("zen.tabs.show-newtab-vertical", false);            // no new-tab button in the vertical tab strip
user_pref("zen.glance.enabled", true);                        // enable Glance (quick peek at links)
user_pref("zen.tabs.ctrl-tab.ignore-essential-tabs", true);   // Ctrl+Tab skips essential/pinned tabs
user_pref("zen.folders.search.hover-delay", 200);             // ms before a folder opens on hover
user_pref("zen.theme.gradient.show-custom-colors", true);     // allow custom gradient colours in themes
user_pref("zen.workspaces.open-new-tab-if-last-unpinned-tab-is-closed", true); // keep an empty tab per workspace

// ─── Search & URL bar ────────────────────────────────────────────────────────
user_pref("browser.urlbar.placeholderName", "Google");
user_pref("browser.urlbar.placeholderName.private", "Google");
user_pref("browser.search.suggest.enabled", true);            // search suggestions on
user_pref("browser.urlbar.showSearchSuggestionsFirst", false); // history/bookmarks before suggestions

// ─── Bookmarks ───────────────────────────────────────────────────────────────
user_pref("browser.toolbars.bookmarks.visibility", "always"); // always show the bookmarks toolbar

// ─── Developer & custom styling ──────────────────────────────────────────────
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // enable userChrome.css / userContent.css
user_pref("devtools.debugger.remote-enabled", true);          // allow remote debugging
user_pref("devtools.chrome.enabled", true);                   // enable the browser toolbox / chrome devtools

// ─── Tab unloading (memory saving) ───────────────────────────────────────────
user_pref("browser.tabs.min_inactive_duration_before_unload", 300000); // 5 min idle before a tab can unload
user_pref("browser.tabs.unloadOnLowMemory", true);            // unload background tabs when RAM is low
user_pref("browser.tabs.fadeOutUnloadedTabs", true);          // dim tabs that have been unloaded

// ─── Display scaling ─────────────────────────────────────────────────────────
user_pref("layout.css.devPixelsPerPx", "0.85");               // global zoom (< 1 = smaller UI)

// ─── Smooth scrolling ────────────────────────────────────────────────────────
user_pref("general.smoothScroll.msdPhysics.continuousMotionMaxDeltaMS", 250);
user_pref("general.smoothScroll.msdPhysics.motionBeginSpringConstant", 450);
user_pref("general.smoothScroll.msdPhysics.regularSpringConstant", 450);
user_pref("general.smoothScroll.msdPhysics.slowdownMinDeltaMS", 50);
user_pref("general.smoothScroll.msdPhysics.slowdownMinDeltaRatio", "0.4");
user_pref("general.smoothScroll.msdPhysics.slowdownSpringConstant", 5000);
user_pref("toolkit.scrollbox.horizontalScrollDistance", 4);   // horizontal wheel step
user_pref("toolkit.scrollbox.verticalScrollDistance", 5);     // vertical wheel step
user_pref("mousewheel.min_line_scroll_amount", 30);           // min pixels per wheel notch

// ─── Sidebar Expand on Hover Mod ─────────────────────────────────────────────
user_pref("mod.autoexpand.animation_duration", "200ms");
user_pref("mod.autoexpand.animation_delay", "0ms");
user_pref("mod.autoexpand.collapse_delay", "100ms");
user_pref("mod.autoexpand.expanded_width", "450px");          // sidebar width when expanded
user_pref("mod.autoexpand.collapsed_width", "45px");          // sidebar width when collapsed
user_pref("mod.autoexpand.essentials_vertical", false);
user_pref("mod.autoexpand.fade_sleeping_tabs", true);         // dim unloaded/sleeping tabs
user_pref("mod.autoexpand.hide_workspace_indicator", false);
user_pref("mod.autoexpand.remove_line_separator", false);
user_pref("mod.autoexpand.performance_mode", "potato");       // lightest animations preset
