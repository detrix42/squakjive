import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ["selector", "display"]

  static values = {
    selectedCircleId: {
      type: Number,
      defaultValue: null,
      nullable: true
    },
    circleRole: {
      type: String,
      default: ''
    }
  }

  connect() {
    console.log('circles controller connected role:', this.circleRoleValue)
    console.log('selected circle id:', this.selectedCircleIdValue)
    const tgt = this.element.querySelector(`#circle-id-${this.selectedCircleIdValue}`)
    tgt.classList.add('selected')

    if (this.circleRoleValue === 'display') {
      this.element.addEventListener('circle-selection:circleSelected', this.handleCircleSelection)
    }


  }

  disconnect() {
    if (this.circleRoleValue === 'display') {
      this.element.removeEventListener('circle-selection:circleSelected', this.handleCircleSelection)
    }
  }

  handleCircleSelection = (event) => {
    // Extract circle_id from the event's detail
    const circleId = event.detail.circleId;
    console.log(`Received circle_id: ${circleId}`);

    // Now use it! Example: Update the content target (or fetch squaks via AJAX)
    if (this.hasContentTarget) {
      this.contentTarget.innerHTML = `Loading squaks for circle ${circleId}...`;
      // Real app: Fetch data, e.g., fetch(`/circles/${circleId}/squaks`).then(...)
    }
  }

  // Action: Called on click in the selector's <li>
  select(event) {
    // Only run if this is the selector instance
    if (this.roleValue !== "selector") return;

    // Get circle_id from the clicked element
    const circleId = event.currentTarget.dataset.circleId;
    console.log(`Selected circle_id: ${circleId}`);

    // Create and dispatch a custom event with circle_id in detail
    const customEvent = new CustomEvent("circle:selected", {
      detail: { circleId: circleId },
      bubbles: true  // Allows bubbling if needed, but we're using window
    });
    window.dispatchEvent(customEvent);  // Global dispatch
  }
}
