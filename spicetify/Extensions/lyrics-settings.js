// lyrics-settings: Spicy Lyrics keeps its settings only in Spotify's
// localStorage ("SL:settings") and has no export of its own. This adds
// "Export / Import Spicy Lyrics settings" to the profile menu, a JSON file
// like Marketplace's backup — keep it as Dotfiles/spicetify/spicy-lyrics-settings.json.
(function lyricsSettings() {
  const KEY = "SL:settings";
  const { Menu, showNotification } = Spicetify;
  if (!Menu || !showNotification) return setTimeout(lyricsSettings, 300);

  const types = [{ description: "JSON files", accept: { "application/json": [".json"] } }];

  new Menu.Item("Export Spicy Lyrics settings", false, async () => {
    const s = localStorage.getItem(KEY);
    if (!s) return showNotification("Spicy Lyrics has no settings yet", true);
    try {
      const file = await window.showSaveFilePicker({ suggestedName: "spicy-lyrics-settings.json", types });
      const w = await file.createWritable();
      await w.write(JSON.stringify(JSON.parse(s), null, 2) + "\n");
      await w.close();
      showNotification("Spicy Lyrics settings exported");
    } catch (e) {
      if (e.name !== "AbortError") showNotification(String(e), true);
    }
  }).register();

  new Menu.Item("Import Spicy Lyrics settings", false, async () => {
    try {
      const [file] = await window.showOpenFilePicker({ types });
      const settings = JSON.parse(await (await file.getFile()).text());
      if (typeof settings !== "object" || !("lyricsSize" in settings)) throw new Error("Not Spicy Lyrics settings");
      localStorage.setItem(KEY, JSON.stringify(settings));
      location.reload();
    } catch (e) {
      if (e.name !== "AbortError") showNotification(String(e), true);
    }
  }).register();
})();
