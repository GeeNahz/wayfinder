// ChurchMap: shows churches as pins on a map.
//
// - Initial pins come from the `data-markers` JSON attribute.
// - The LiveView can replace them with push_event(socket, "map:churches", %{markers: [...], origin: ...}),
//   e.g. after the filters change. `origin` ({lat, lng}) marks the visitor's location for "near me".
//
// Each marker looks like: {id, name, lat, lng, address, denomination, url}
//
// Usage: <div id="..." phx-hook="ChurchMap" phx-update="ignore" data-markers={Jason.encode!(markers)}></div>
import {createMap, pinIcon, L, DEFAULT_CENTER, DEFAULT_ZOOM} from "../maps"

// Builds popup content with DOM APIs (never innerHTML) because church names
// are typed in by the public.
function popupContent(marker) {
  const box = document.createElement("div")
  box.className = "space-y-1"

  const title = document.createElement(marker.url ? "a" : "p")
  title.className = "block font-semibold text-brand hover:underline"
  title.textContent = marker.name
  if (marker.url) title.href = marker.url
  box.appendChild(title)

  for (const text of [marker.denomination, marker.address]) {
    if (!text) continue
    const line = document.createElement("p")
    line.style.margin = "0"
    line.textContent = text
    box.appendChild(line)
  }

  return box
}

export default {
  mounted() {
    this.map = createMap(this.el)
    this.pins = L.layerGroup().addTo(this.map)
    this.map.setView(DEFAULT_CENTER, DEFAULT_ZOOM)

    this.showMarkers(JSON.parse(this.el.dataset.markers || "[]"), null)
    this.handleEvent("map:churches", ({markers, origin}) => this.showMarkers(markers, origin))

    setTimeout(() => this.map.invalidateSize(), 0)
  },

  showMarkers(markers, origin) {
    this.pins.clearLayers()
    const points = []

    for (const marker of markers) {
      L.marker([marker.lat, marker.lng], {icon: pinIcon(), title: marker.name})
        .bindPopup(popupContent(marker))
        .addTo(this.pins)
      points.push([marker.lat, marker.lng])
    }

    if (origin) {
      L.circleMarker([origin.lat, origin.lng], {
        radius: 8, color: "#fff", weight: 3, fillColor: "#2563eb", fillOpacity: 1,
      }).bindTooltip("You are here").addTo(this.pins)
      points.push([origin.lat, origin.lng])
    }

    if (points.length === 1) {
      this.map.setView(points[0], 15)
    } else if (points.length > 1) {
      this.map.fitBounds(points, {padding: [40, 40], maxZoom: 15})
    }
  },

  destroyed() {
    this.map?.remove()
  },
}
