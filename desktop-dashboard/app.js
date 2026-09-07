"use strict";

/* --------------------------------------------------------------------------
   Customize these two arrays. Local paths, remote URLs, and data URLs work.
   Add an `audio` path to a track to use a real audio file; leave it empty for
   the animated mock player.
---------------------------------------------------------------------------- */
const WALLPAPERS = [
  {
    id: "aurora",
    name: "Midnight Aurora",
    mood: "quiet / electric",
    src: "assets/wallpapers/aurora.svg",
    accent: "#5ee7df"
  },
  {
    id: "ember",
    name: "Ember Dunes",
    mood: "warm / cinematic",
    src: "assets/wallpapers/ember.svg",
    accent: "#ff7a4d"
  },
  {
    id: "cobalt",
    name: "Cobalt Structure",
    mood: "precise / nocturnal",
    src: "assets/wallpapers/cobalt.svg",
    accent: "#4cbcff"
  },
  {
    id: "sakura",
    name: "Sakura Night",
    mood: "soft / vivid",
    src: "assets/wallpapers/sakura.svg",
    accent: "#ff6682"
  },
  {
    id: "jade",
    name: "Jade Current",
    mood: "calm / organic",
    src: "assets/wallpapers/jade.svg",
    accent: "#45dfa8"
  },
  {
    id: "mono",
    name: "Monolith",
    mood: "still / monochrome",
    src: "assets/wallpapers/mono.svg",
    accent: "#c8ccd6"
  }
];

const TRACKS = [
  {
    title: "Afterglow",
    artist: "Lunar Static",
    art: "assets/wallpapers/aurora.svg",
    duration: 238,
    startAt: 43,
    audio: ""
  },
  {
    title: "Heat Mirage",
    artist: "Night Transit",
    art: "assets/wallpapers/ember.svg",
    duration: 194,
    startAt: 0,
    audio: ""
  },
  {
    title: "Blue Geometry",
    artist: "Polar Form",
    art: "assets/wallpapers/cobalt.svg",
    duration: 267,
    startAt: 0,
    audio: ""
  },
  {
    title: "Quiet Current",
    artist: "Mori Sequence",
    art: "assets/wallpapers/jade.svg",
    duration: 221,
    startAt: 0,
    audio: ""
  }
];

const APPLICATIONS = [
  { id: "wallpapers", label: "Wallpapers", detail: "Open the coverflow deck", icon: "image", kind: "app" },
  { id: "music", label: "Music", detail: "Focus the now-playing panel", icon: "music", kind: "app" },
  { id: "files", label: "Files", detail: "Browse local collections", icon: "folder", kind: "app" },
  { id: "terminal", label: "Terminal", detail: "Open a quiet command window", icon: "terminal", kind: "app" },
  { id: "settings", label: "Settings", detail: "Tune the desktop experience", icon: "sliders", kind: "app" },
  { id: "next-wallpaper", label: "Next wallpaper", detail: "Move the coverflow one step right", icon: "image", kind: "action" },
  { id: "toggle-player", label: "Play / pause", detail: "Toggle the Spotify mock player", icon: "music", kind: "action" }
];

const $ = (selector, parent = document) => parent.querySelector(selector);
const $$ = (selector, parent = document) => [...parent.querySelectorAll(selector)];
const root = document.documentElement;

const ui = {
  backgroundLayers: $$(".wallpaper-layer"),
  wallpaperTrack: $("#wallpaperTrack"),
  wallpaperViewport: $("#coverflowViewport"),
  wallpaperIndex: $("#wallpaperIndex"),
  wallpaperName: $("#wallpaperName"),
  wallpaperMood: $("#wallpaperMood"),
  wallpaperPagination: $("#wallpaperPagination"),
  wallpaperPanel: $(".wallpaper-tile"),
  previousWallpaper: $("#previousWallpaper"),
  nextWallpaper: $("#nextWallpaper"),
  musicWidget: $("#musicWidget"),
  albumWrap: $(".album-wrap"),
  albumArt: $("#albumArt"),
  trackTitle: $("#trackTitle"),
  trackArtist: $("#trackArtist"),
  trackNumber: $("#trackNumber"),
  seekBar: $("#seekBar"),
  currentTime: $("#currentTime"),
  duration: $("#duration"),
  playPause: $("#playPause"),
  previousTrack: $("#previousTrack"),
  nextTrack: $("#nextTrack"),
  rewindTrack: $("#rewindTrack"),
  forwardTrack: $("#forwardTrack"),
  volumeBar: $("#volumeBar"),
  volumeValue: $("#volumeValue"),
  audio: $("#audioPlayer"),
  menubarTime: $("#menubarTime"),
  largeClock: $("#largeClock"),
  fullDate: $("#fullDate"),
  launcher: $("#launcher"),
  launcherInput: $("#launcherInput"),
  launcherResults: $("#launcherResults"),
  commandTrigger: $("#commandTrigger"),
  launcherPrompt: $("#launcherPrompt"),
  appWindow: $("#appWindow"),
  appWindowTitle: $("#appWindowTitle"),
  appWindowContent: $("#appWindowContent"),
  closeAppWindow: $("#closeAppWindow"),
  toast: $("#toast"),
  toastText: $("#toastText")
};

const state = {
  wallpaperIndex: 0,
  activeBackground: 0,
  trackIndex: 0,
  elapsed: TRACKS[0].startAt,
  playing: false,
  launcherSelection: 0,
  launcherItems: [...APPLICATIONS],
  toastTimer: 0,
  albumTimer: 0,
  launcherCloseTimer: 0,
  appCloseTimer: 0,
  lastPlayerFrame: 0,
  lastPlayerPaint: 0
};

function wrapIndex(value, length) {
  return ((value % length) + length) % length;
}

function hexToRgb(hex) {
  const clean = hex.replace("#", "");
  const value = Number.parseInt(clean.length === 3
    ? clean.split("").map(character => character + character).join("")
    : clean, 16);
  return [(value >> 16) & 255, (value >> 8) & 255, value & 255];
}

function mixRgb(color, target, amount) {
  return color.map((channel, index) => Math.round(channel + (target[index] - channel) * amount));
}

function relativeLuminance(rgb) {
  const linear = rgb.map(channel => {
    const value = channel / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722;
}

function applyAccent(hex) {
  const accent = hexToRgb(hex);
  const strong = mixRgb(accent, [255, 255, 255], 0.17);
  const luminance = relativeLuminance(accent);
  const dark = [3, 12, 15];
  const light = [247, 249, 252];
  const darkContrast = (luminance + 0.05) / (relativeLuminance(dark) + 0.05);
  const lightContrast = (relativeLuminance(light) + 0.05) / (luminance + 0.05);
  const foreground = darkContrast >= lightContrast ? dark : light;
  root.style.setProperty("--accent", accent.join(" "));
  root.style.setProperty("--accent-strong", strong.join(" "));
  root.style.setProperty("--accent-contrast", foreground.join(" "));
}

function showToast(message) {
  window.clearTimeout(state.toastTimer);
  ui.toastText.textContent = message;
  ui.toast.classList.add("is-visible");
  state.toastTimer = window.setTimeout(() => ui.toast.classList.remove("is-visible"), 1800);
}

/* --------------------------------------------------------------------------
   Wallpaper coverflow
---------------------------------------------------------------------------- */
function createWallpaperDeck() {
  const cards = WALLPAPERS.map((wallpaper, index) => {
    const card = document.createElement("button");
    card.type = "button";
    card.className = "wallpaper-card";
    card.dataset.index = String(index);
    card.setAttribute("role", "option");
    card.setAttribute("aria-label", `Use ${wallpaper.name} wallpaper`);
    card.innerHTML = `
      <img src="${wallpaper.src}" alt="" draggable="false">
      <span class="wallpaper-card__badge"><i></i> active</span>
    `;
    card.addEventListener("click", () => {
      if (!ui.wallpaperViewport.classList.contains("is-dragging")) {
        selectWallpaper(index);
      }
    });
    ui.wallpaperTrack.append(card);
    return card;
  });

  WALLPAPERS.forEach((wallpaper, index) => {
    const dot = document.createElement("button");
    dot.type = "button";
    dot.className = "pagination-dot";
    dot.setAttribute("aria-label", `Select ${wallpaper.name}`);
    dot.addEventListener("click", () => selectWallpaper(index));
    ui.wallpaperPagination.append(dot);
  });

  ui.wallpaperViewport.tabIndex = 0;
  ui.wallpaperViewport.setAttribute("aria-label", "Wallpaper coverflow. Use left and right arrow keys to browse.");
  return cards;
}

const wallpaperCards = createWallpaperDeck();
const paginationDots = $$(".pagination-dot", ui.wallpaperPagination);

function normalizedCardOffset(cardIndex) {
  let offset = cardIndex - state.wallpaperIndex;
  const half = WALLPAPERS.length / 2;
  if (offset > half) offset -= WALLPAPERS.length;
  if (offset < -half) offset += WALLPAPERS.length;
  return offset;
}

function renderCoverflow() {
  const viewportWidth = ui.wallpaperViewport.clientWidth || 900;
  const spacing = Math.min(310, Math.max(155, viewportWidth * 0.255));

  wallpaperCards.forEach((card, index) => {
    const offset = normalizedCardOffset(index);
    const distance = Math.abs(offset);
    const translateX = offset * spacing;
    const translateZ = -Math.min(distance, 3) * 155;
    const rotateY = offset === 0 ? 0 : offset > 0 ? -34 : 34;
    const scale = offset === 0 ? 1 : Math.max(0.72, 0.88 - distance * 0.055);
    const opacity = distance > 2.35 ? 0 : Math.max(0.26, 1 - distance * 0.3);

    card.style.zIndex = String(20 - Math.round(distance * 3));
    card.style.opacity = String(opacity);
    card.style.filter = `brightness(${Math.max(0.48, 1 - distance * 0.18)}) saturate(${Math.max(0.68, 1 - distance * 0.1)})`;
    card.style.pointerEvents = distance > 2.35 ? "none" : "auto";
    card.style.transform = `translate(-50%, -50%) translate3d(${translateX}px, 0, ${translateZ}px) rotateY(${rotateY}deg) scale(${scale})`;
    card.classList.toggle("is-selected", index === state.wallpaperIndex);
    card.setAttribute("aria-selected", String(index === state.wallpaperIndex));
    card.tabIndex = index === state.wallpaperIndex ? 0 : -1;
  });

  paginationDots.forEach((dot, index) => {
    dot.classList.toggle("is-active", index === state.wallpaperIndex);
    dot.setAttribute("aria-current", index === state.wallpaperIndex ? "true" : "false");
  });
}

function crossfadeBackground(wallpaper) {
  const nextLayerIndex = state.activeBackground === 0 ? 1 : 0;
  const currentLayer = ui.backgroundLayers[state.activeBackground];
  const nextLayer = ui.backgroundLayers[nextLayerIndex];
  nextLayer.style.backgroundImage = `url("${wallpaper.src}")`;

  requestAnimationFrame(() => {
    nextLayer.classList.add("is-visible");
    currentLayer.classList.remove("is-visible");
    state.activeBackground = nextLayerIndex;
  });
}

function selectWallpaper(index, options = {}) {
  const nextIndex = wrapIndex(index, WALLPAPERS.length);
  const wallpaper = WALLPAPERS[nextIndex];
  const changed = nextIndex !== state.wallpaperIndex;
  state.wallpaperIndex = nextIndex;

  applyAccent(wallpaper.accent);
  ui.wallpaperIndex.textContent = String(nextIndex + 1).padStart(2, "0");
  ui.wallpaperName.textContent = wallpaper.name;
  ui.wallpaperMood.textContent = wallpaper.mood;
  renderCoverflow();

  if (changed || options.forceBackground) {
    crossfadeBackground(wallpaper);
    if (!options.silent) showToast(`${wallpaper.name} applied`);
  }
}

function stepWallpaper(direction) {
  selectWallpaper(state.wallpaperIndex + direction);
}

ui.previousWallpaper.addEventListener("click", () => stepWallpaper(-1));
ui.nextWallpaper.addEventListener("click", () => stepWallpaper(1));

let wheelLocked = false;
ui.wallpaperViewport.addEventListener("wheel", event => {
  event.preventDefault();
  if (wheelLocked) return;
  const movement = Math.abs(event.deltaX) > Math.abs(event.deltaY) ? event.deltaX : event.deltaY;
  if (Math.abs(movement) < 5) return;
  wheelLocked = true;
  stepWallpaper(movement > 0 ? 1 : -1);
  window.setTimeout(() => { wheelLocked = false; }, 420);
}, { passive: false });

ui.wallpaperViewport.addEventListener("keydown", event => {
  if (event.key === "ArrowLeft") {
    event.preventDefault();
    stepWallpaper(-1);
  }
  if (event.key === "ArrowRight") {
    event.preventDefault();
    stepWallpaper(1);
  }
  if (event.key === "Home") selectWallpaper(0);
  if (event.key === "End") selectWallpaper(WALLPAPERS.length - 1);
});

let pointerStart = 0;
let pointerShift = 0;
let pointerId = null;
ui.wallpaperViewport.addEventListener("pointerdown", event => {
  pointerId = event.pointerId;
  pointerStart = event.clientX;
  pointerShift = 0;
  ui.wallpaperViewport.setPointerCapture(pointerId);
});

ui.wallpaperViewport.addEventListener("pointermove", event => {
  if (event.pointerId !== pointerId) return;
  pointerShift = event.clientX - pointerStart;
  if (Math.abs(pointerShift) > 6) {
    ui.wallpaperViewport.classList.add("is-dragging");
    ui.wallpaperTrack.style.transform = `translateX(${pointerShift * 0.16}px)`;
  }
});

function finishWallpaperDrag(event) {
  if (event.pointerId !== pointerId) return;
  ui.wallpaperTrack.style.transform = "";
  if (Math.abs(pointerShift) > 45) stepWallpaper(pointerShift < 0 ? 1 : -1);
  window.setTimeout(() => ui.wallpaperViewport.classList.remove("is-dragging"), 0);
  pointerId = null;
}

ui.wallpaperViewport.addEventListener("pointerup", finishWallpaperDrag);
ui.wallpaperViewport.addEventListener("pointercancel", finishWallpaperDrag);
window.addEventListener("resize", renderCoverflow);
WALLPAPERS.forEach(wallpaper => { const preload = new Image(); preload.src = wallpaper.src; });

/* --------------------------------------------------------------------------
   Mock player with optional real audio files
---------------------------------------------------------------------------- */
function formatTime(seconds) {
  const safe = Math.max(0, Math.round(Number.isFinite(seconds) ? seconds : 0));
  return `${Math.floor(safe / 60)}:${String(safe % 60).padStart(2, "0")}`;
}

function activeTrack() {
  return TRACKS[state.trackIndex];
}

function trackDuration() {
  if (activeTrack().audio && Number.isFinite(ui.audio.duration)) return ui.audio.duration;
  return activeTrack().duration;
}

function paintPlayer() {
  const duration = trackDuration();
  const percent = duration ? Math.min(100, (state.elapsed / duration) * 100) : 0;
  ui.seekBar.value = String(percent);
  ui.seekBar.style.setProperty("--range", `${percent}%`);
  ui.currentTime.textContent = formatTime(state.elapsed);
  ui.duration.textContent = formatTime(duration);
  ui.musicWidget.classList.toggle("is-playing", state.playing);
  ui.playPause.setAttribute("aria-label", state.playing ? "Pause" : "Play");
}

function loadTrack(index, preservePlayback = state.playing) {
  state.trackIndex = wrapIndex(index, TRACKS.length);
  const track = activeTrack();
  state.elapsed = track.startAt || 0;

  window.clearTimeout(state.albumTimer);
  ui.albumWrap.classList.add("is-changing");
  state.albumTimer = window.setTimeout(() => {
    ui.albumArt.src = track.art;
    ui.albumArt.alt = `${track.title} album artwork`;
    ui.albumWrap.classList.remove("is-changing");
  }, 150);

  ui.trackTitle.textContent = track.title;
  ui.trackArtist.textContent = track.artist;
  ui.trackNumber.textContent = `${String(state.trackIndex + 1).padStart(2, "0")} / ${String(TRACKS.length).padStart(2, "0")}`;

  ui.audio.pause();
  ui.audio.removeAttribute("src");
  if (track.audio) {
    ui.audio.src = track.audio;
    ui.audio.addEventListener("loadedmetadata", () => {
      ui.audio.currentTime = Math.min(state.elapsed, ui.audio.duration || state.elapsed);
    }, { once: true });
    if (preservePlayback) {
      ui.audio.play().catch(() => {
        state.playing = false;
        showToast("Browser blocked audio playback");
        paintPlayer();
      });
    }
  }

  state.playing = preservePlayback;
  paintPlayer();
}

function setPlaying(playing) {
  state.playing = playing;
  const track = activeTrack();
  if (track.audio) {
    if (playing) {
      ui.audio.play().catch(() => {
        state.playing = false;
        showToast("Add a valid audio file or allow playback");
        paintPlayer();
      });
    } else {
      ui.audio.pause();
    }
  }
  paintPlayer();
}

function seekTo(seconds) {
  state.elapsed = Math.max(0, Math.min(trackDuration(), seconds));
  if (activeTrack().audio) ui.audio.currentTime = state.elapsed;
  paintPlayer();
}

ui.playPause.addEventListener("click", () => setPlaying(!state.playing));
ui.previousTrack.addEventListener("click", () => loadTrack(state.trackIndex - 1));
ui.nextTrack.addEventListener("click", () => loadTrack(state.trackIndex + 1));
ui.rewindTrack.addEventListener("click", () => seekTo(state.elapsed - 10));
ui.forwardTrack.addEventListener("click", () => seekTo(state.elapsed + 10));
ui.seekBar.addEventListener("input", () => seekTo(trackDuration() * (Number(ui.seekBar.value) / 100)));

function updateVolume() {
  const volume = Number(ui.volumeBar.value);
  ui.audio.volume = volume / 100;
  ui.volumeValue.textContent = String(volume);
  ui.volumeBar.style.setProperty("--range", `${volume}%`);
}
ui.volumeBar.addEventListener("input", updateVolume);
ui.audio.addEventListener("ended", () => loadTrack(state.trackIndex + 1, true));
ui.audio.addEventListener("loadedmetadata", paintPlayer);

function playerLoop(timestamp) {
  const frameDelta = state.lastPlayerFrame ? (timestamp - state.lastPlayerFrame) / 1000 : 0;
  state.lastPlayerFrame = timestamp;

  if (state.playing) {
    if (activeTrack().audio) {
      state.elapsed = ui.audio.currentTime;
    } else {
      state.elapsed += frameDelta;
    }

    if (state.elapsed >= trackDuration()) {
      loadTrack(state.trackIndex + 1, true);
    }
  }

  if (!state.lastPlayerPaint || timestamp - state.lastPlayerPaint > 120) {
    paintPlayer();
    state.lastPlayerPaint = timestamp;
  }
  requestAnimationFrame(playerLoop);
}

/* --------------------------------------------------------------------------
   Clock, launcher, mock application windows
---------------------------------------------------------------------------- */
function updateClock() {
  const now = new Date();
  const compactTime = new Intl.DateTimeFormat(undefined, { hour: "2-digit", minute: "2-digit", hour12: false }).format(now);
  const date = new Intl.DateTimeFormat(undefined, { weekday: "long", day: "numeric", month: "long" }).format(now);
  const iso = now.toISOString();

  ui.menubarTime.textContent = compactTime;
  ui.menubarTime.dateTime = iso;
  ui.largeClock.textContent = compactTime;
  ui.largeClock.dateTime = iso;
  ui.fullDate.textContent = date;
}

function iconUse(name) {
  return `<svg><use href="#icon-${name}"></use></svg>`;
}

function renderLauncher() {
  const query = ui.launcherInput.value.trim().toLowerCase();
  state.launcherItems = APPLICATIONS.filter(item => `${item.label} ${item.detail} ${item.kind}`.toLowerCase().includes(query));
  state.launcherSelection = Math.min(state.launcherSelection, Math.max(0, state.launcherItems.length - 1));

  ui.launcherResults.innerHTML = "";
  if (!state.launcherItems.length) {
    const empty = document.createElement("p");
    empty.className = "launcher-item";
    empty.textContent = "No matching apps or actions.";
    ui.launcherResults.append(empty);
    return;
  }

  state.launcherItems.forEach((item, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `launcher-item${index === state.launcherSelection ? " is-selected" : ""}`;
    button.setAttribute("role", "option");
    button.setAttribute("aria-selected", String(index === state.launcherSelection));
    button.innerHTML = `
      <span class="launcher-item__icon">${iconUse(item.icon)}</span>
      <span><strong>${item.label}</strong><small>${item.detail}</small></span>
      <span class="launcher-item__action">${item.kind}</span>
    `;
    button.addEventListener("mouseenter", () => {
      state.launcherSelection = index;
      $$(".launcher-item", ui.launcherResults).forEach((result, resultIndex) => result.classList.toggle("is-selected", resultIndex === index));
    });
    button.addEventListener("click", () => executeLauncherItem(item));
    ui.launcherResults.append(button);
  });
}

function openLauncher() {
  window.clearTimeout(state.launcherCloseTimer);
  ui.launcher.hidden = false;
  state.launcherSelection = 0;
  ui.launcherInput.value = "";
  renderLauncher();
  requestAnimationFrame(() => {
    ui.launcher.classList.add("is-open");
    ui.launcherInput.focus();
  });
}

function closeLauncher() {
  ui.launcher.classList.remove("is-open");
  state.launcherCloseTimer = window.setTimeout(() => {
    ui.launcher.hidden = true;
    ui.commandTrigger.focus({ preventScroll: true });
  }, 280);
}

function focusTile(element) {
  element.scrollIntoView({ behavior: "smooth", block: "center" });
  element.animate([
    { boxShadow: "inset 0 1px 0 rgb(255 255 255 / .07), 0 0 0 1px rgb(var(--accent) / 0), 0 28px 80px rgb(0 0 0 / .38)" },
    { boxShadow: "inset 0 1px 0 rgb(255 255 255 / .07), 0 0 0 2px rgb(var(--accent) / .34), 0 34px 95px rgb(0 0 0 / .45)" },
    { boxShadow: "inset 0 1px 0 rgb(255 255 255 / .07), 0 0 0 1px rgb(var(--accent) / 0), 0 28px 80px rgb(0 0 0 / .38)" }
  ], { duration: 760, easing: "cubic-bezier(.22, 1, .36, 1)" });
}

const APP_CONTENT = {
  files: {
    title: "Files — Home",
    html: `<div class="file-grid">
      <article class="file-card">${iconUse("folder")}<strong>Wallpapers</strong><span>6 local items</span></article>
      <article class="file-card">${iconUse("folder")}<strong>Music</strong><span>4 mock tracks</span></article>
      <article class="file-card">${iconUse("folder")}<strong>Projects</strong><span>12 directories</span></article>
      <article class="file-card">${iconUse("image")}<strong>aurora.svg</strong><span>vector image</span></article>
      <article class="file-card">${iconUse("image")}<strong>cobalt.svg</strong><span>vector image</span></article>
      <article class="file-card">${iconUse("image")}<strong>jade.svg</strong><span>vector image</span></article>
    </div>`
  },
  terminal: {
    title: "Terminal — still",
    html: `<div class="fake-terminal">
      <p><span class="prompt">still@desktop</span> <span class="muted">~</span> fastfetch</p>
      <p>OS&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; minimal web desktop</p>
      <p>Shell&nbsp;&nbsp;&nbsp;&nbsp; vanilla javascript</p>
      <p>WM&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; css grid + glass</p>
      <p>Theme&nbsp;&nbsp;&nbsp;&nbsp; <span class="prompt">wallpaper reactive</span></p>
      <p class="muted">Ready. Type Ctrl+K to open the launcher.</p>
      <p><span class="prompt">still@desktop</span> <span class="muted">~</span> <span class="terminal-caret">▌</span></p>
    </div>`
  },
  settings: {
    title: "Settings — Appearance",
    html: `<div class="setting-list">
      <div class="setting-row"><div><strong>Glass surfaces</strong><span>Blur and saturate tiled windows</span></div><i class="fake-toggle"></i></div>
      <div class="setting-row"><div><strong>Wallpaper accent</strong><span>Follow the active wallpaper palette</span></div><i class="fake-toggle"></i></div>
      <div class="setting-row"><div><strong>Motion</strong><span>Use smooth coverflow transitions</span></div><i class="fake-toggle"></i></div>
      <div class="setting-row"><div><strong>Quiet mode</strong><span>Keep the interface visually minimal</span></div><i class="fake-toggle"></i></div>
    </div>`
  }
};

function openAppWindow(id) {
  const content = APP_CONTENT[id];
  if (!content) return;
  window.clearTimeout(state.appCloseTimer);
  ui.appWindowTitle.textContent = content.title;
  ui.appWindowContent.innerHTML = content.html;
  ui.appWindow.hidden = false;
  requestAnimationFrame(() => ui.appWindow.classList.add("is-open"));
}

function closeAppWindow() {
  ui.appWindow.classList.remove("is-open");
  state.appCloseTimer = window.setTimeout(() => { ui.appWindow.hidden = true; }, 260);
}

function launch(id) {
  $$(".dock__item").forEach(item => item.classList.toggle("is-active", item.dataset.app === id));
  if (id === "wallpapers") focusTile(ui.wallpaperPanel);
  else if (id === "music") focusTile(ui.musicWidget);
  else openAppWindow(id);
}

function executeLauncherItem(item) {
  closeLauncher();
  if (item.id === "next-wallpaper") stepWallpaper(1);
  else if (item.id === "toggle-player") setPlaying(!state.playing);
  else launch(item.id);
}

ui.commandTrigger.addEventListener("click", openLauncher);
ui.launcherPrompt.addEventListener("click", openLauncher);
$$("[data-close-launcher]").forEach(button => button.addEventListener("click", closeLauncher));
ui.launcherInput.addEventListener("input", () => {
  state.launcherSelection = 0;
  renderLauncher();
});
ui.launcherInput.addEventListener("keydown", event => {
  if (event.key === "ArrowDown") {
    event.preventDefault();
    state.launcherSelection = wrapIndex(state.launcherSelection + 1, state.launcherItems.length || 1);
    renderLauncher();
  } else if (event.key === "ArrowUp") {
    event.preventDefault();
    state.launcherSelection = wrapIndex(state.launcherSelection - 1, state.launcherItems.length || 1);
    renderLauncher();
  } else if (event.key === "Enter" && state.launcherItems.length) {
    event.preventDefault();
    executeLauncherItem(state.launcherItems[state.launcherSelection]);
  }
});

ui.closeAppWindow.addEventListener("click", closeAppWindow);
$$(".dock__item").forEach(button => button.addEventListener("click", () => launch(button.dataset.app)));
$$('.workspace-dot').forEach(button => button.addEventListener("click", () => {
  $$('.workspace-dot').forEach(dot => {
    const active = dot === button;
    dot.classList.toggle("is-active", active);
    dot.setAttribute("aria-current", active ? "true" : "false");
  });
  $(".dashboard").animate([{ opacity: .55, transform: "scale(.992)" }, { opacity: 1, transform: "scale(1)" }], { duration: 380, easing: "ease-out" });
}));

document.addEventListener("keydown", event => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
    event.preventDefault();
    ui.launcher.hidden ? openLauncher() : closeLauncher();
    return;
  }
  if (event.key === "Escape") {
    if (!ui.launcher.hidden) closeLauncher();
    else if (!ui.appWindow.hidden) closeAppWindow();
    return;
  }
  const isTyping = ["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName);
  if (!isTyping && ui.launcher.hidden && event.key === "ArrowLeft") stepWallpaper(-1);
  if (!isTyping && ui.launcher.hidden && event.key === "ArrowRight") stepWallpaper(1);
  if (!isTyping && ui.launcher.hidden && event.code === "Space") {
    event.preventDefault();
    setPlaying(!state.playing);
  }
});

/* Initial paint */
ui.backgroundLayers[0].style.backgroundImage = `url("${WALLPAPERS[0].src}")`;
selectWallpaper(0, { silent: true });
loadTrack(0, false);
updateVolume();
updateClock();
window.setInterval(updateClock, 15_000);
requestAnimationFrame(playerLoop);

// Small public API for experiments or a future Spotify adapter.
window.StillDashboard = {
  wallpapers: WALLPAPERS,
  tracks: TRACKS,
  selectWallpaper,
  loadTrack,
  setPlaying,
  openLauncher
};
