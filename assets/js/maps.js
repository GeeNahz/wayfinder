// Small helpers shared by every map hook (see assets/js/hooks/).
// Leaflet is installed with pnpm (assets/package.json).
import L from "leaflet"

// OpenStreetMap tiles: free to use with attribution.
const TILE_URL = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
const ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'

// Roughly the centre of the world map, used when we have no coordinates yet.
export const DEFAULT_CENTER = [20, 0]
export const DEFAULT_ZOOM = 2

// Creates a Leaflet map inside `element` with OpenStreetMap tiles.
export function createMap(element, options = {}) {
  const map = L.map(element, {scrollWheelZoom: false, ...options})
  L.tileLayer(TILE_URL, {maxZoom: 19, attribution: ATTRIBUTION}).addTo(map)
  return map
}

// Our own SVG map pin, styled by the `.wf-pin` CSS class in app.css.
// (Leaflet's default marker uses image files that bundlers often break.)
export function pinIcon() {
  return L.divIcon({
    className: "wf-pin",
    iconSize: [32, 40],
    iconAnchor: [16, 40],
    popupAnchor: [0, -36],
    html: `<svg viewBox="0 0 32 40" width="32" height="40" aria-hidden="true">
      <path fill="currentColor" d="M16 0C7.2 0 0 7 0 15.7 0 27.5 16 40 16 40s16-12.5 16-24.3C32 7 24.8 0 16 0Z"/>
      <circle cx="16" cy="15.5" r="6" fill="white"/>
    </svg>`,
  })
}

export {L}
