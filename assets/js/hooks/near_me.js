// NearMe: a button that asks the browser for the visitor's location and
// sends it to the LiveView as a "located" event (or "locate_failed").
//
// Usage: <button id="..." phx-hook="NearMe" type="button">Near me</button>
export default {
  mounted() {
    this.el.addEventListener("click", () => {
      if (!navigator.geolocation) {
        this.pushEvent("locate_failed", {message: "Your browser can't share its location."})
        return
      }

      this.el.classList.add("opacity-60", "pointer-events-none")

      navigator.geolocation.getCurrentPosition(
        ({coords}) => {
          this.el.classList.remove("opacity-60", "pointer-events-none")
          this.pushEvent("located", {lat: coords.latitude, lng: coords.longitude})
        },
        () => {
          this.el.classList.remove("opacity-60", "pointer-events-none")
          this.pushEvent("locate_failed", {message: "We couldn't get your location. Check your browser's permission."})
        },
        {enableHighAccuracy: false, timeout: 10000, maximumAge: 300000},
      )
    })
  },
}
