import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"
import TurndownService from "turndown"

export default class extends Controller {
  static targets = ["squakindex"]

  static values = {

  }

  connect() {
    console.log("Squak index controller connected")


  }

  disconnect() {

  }

}
