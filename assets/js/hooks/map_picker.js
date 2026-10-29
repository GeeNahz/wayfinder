// MapPicker: lets someone place their church on the map.
//
// - Click the map (or drag the pin) to set the location; we tell the
//   LiveView with a "pin_moved" event so it can fill in latitude/longitude.
// - The LiveView can move the pin with push_event(socket, "map:set_pin", %{lat:, lng:}),
//   e.g. after "Find on map".
//
// Usage: <div id="..." phx-hook="MapPicker" phx-update="ignore" data-lat="..." data-lng="..."></div>
import {createMap, pinIcon, L, DEFAULT_CENTER, DEFAULT_ZOOM} from "../maps"

// ~11cm precision is plenty for a building.
const round = (number) => Math.round(number * 1e6) / 1e6

export default {
  mounted() {
    const lat = parseFloat(this.el.dataset.lat)
    const lng = parseFloat(this.el.dataset.lng)
    const hasLocation = !isNaN(lat) && !isNaN(lng)

    this.map = createMap(this.el)
    this.map.setView(hasLocation ? [lat, lng] : DEFAULT_CENTER, hasLocation ? 16 : DEFAULT_ZOOM)
    if (hasLocation) this.placePin(lat, lng)

    this.map.on("click", (event) => {
      this.placePin(event.latlng.lat, event.latlng.lng)
      this.reportPin()
    })

    this.handleEvent("map:set_pin", ({lat, lng}) => {
      this.placePin(lat, lng)
      this.map.setView([lat, lng], 16)
    })

    // The container may still be resizing when we mount.
    setTimeout(() => this.map.invalidateSize(), 0)
  },

  placePin(lat, lng) {
    if (this.marker) {
      this.marker.setLatLng([lat, lng])
    } else {
      this.marker = L.marker([lat, lng], {icon: pinIcon(), draggable: true}).addTo(this.map)
      this.marker.on("dragend", () => this.reportPin())
    }
  },

  reportPin() {
    const {lat, lng} = this.marker.getLatLng()
    this.pushEvent("pin_moved", {lat: round(lat), lng: round(lng)})
  },

  destroyed() {
    this.map?.remove()
  },
}
