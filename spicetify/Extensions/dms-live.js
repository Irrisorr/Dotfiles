// dms-live: repaints an open Spotify when the wallpaper colors change.
// DMS writes Themes/dms-colors/color.ini, `spicetify refresh -s` turns it into
// the colors.css (and user.css) Spotify loads; this re-reads both every 2 s
// and swaps a stylesheet when its file differs, so no restart is needed.
(function dmsLive() {
  const files = ["colors.css", "user.css"];
  const sheet = (f) => document.querySelector(`link[href^="${f}"]`);
  if (!files.every(sheet)) return setTimeout(dmsLive, 1000);

  const read = (f) => fetch(f, { cache: "no-store" }).then((r) => r.text());
  const last = {};

  setInterval(() => {
    files.forEach(async (f) => {
      let css;
      try {
        css = await read(f);
      } catch {
        return;
      }
      if (last[f] === undefined || css === last[f]) return (last[f] = css);
      last[f] = css;
      const old = sheet(f);
      if (!old) return;
      // The new sheet loads before the old one goes, so nothing flashes.
      const fresh = old.cloneNode();
      fresh.href = `${f}?${Date.now()}`;
      fresh.onload = () => old.remove();
      old.after(fresh);
    });
  }, 2000);
})();
