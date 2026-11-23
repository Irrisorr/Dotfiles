// Live wallpaper colors: DMS rewrites ~/.config/dms/zen.css (matugen) on every
// wallpaper change, but userChrome.css is only read at startup. This loads the
// file as a sheet of its own and swaps it whenever its mtime changes.
//
// AUTHOR level: beats Zen's own styles and the inline per-space colors, while
// userChrome.css and the other mods (user level) still override it.

const POLL_MS = 2000;
const file = PathUtils.join(
  Services.dirsvc.get("Home", Ci.nsIFile).path,
  ".config",
  "dms",
  "zen.css"
);
const utils = window.windowUtils;

let sheet = null;
let mtime = 0;

async function refresh() {
  let stat;
  try {
    stat = await IOUtils.stat(file);
  } catch {
    return; // not generated yet (or Dynamic theme off) — keep what's loaded
  }
  if (stat.lastModified === mtime) return;
  mtime = stat.lastModified;

  // The query string busts the stylesheet cache, so the new colors are read.
  const next = Services.io.newURI(`${PathUtils.toFileURI(file)}?v=${mtime}`);
  utils.loadSheet(next, utils.AUTHOR_SHEET);
  if (sheet) utils.removeSheet(sheet, utils.AUTHOR_SHEET);
  sheet = next;
}

refresh();
const timer = setInterval(refresh, POLL_MS);
window.addEventListener("unload", () => clearInterval(timer), { once: true });
