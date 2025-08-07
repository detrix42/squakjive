import consumer from "channels/consumer"

consumer.subscriptions.create("SquaksChannel", {
  connected() {
    // Called when the subscription is ready for use on the server
    console.log("Connected to SquaksChannel");
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
    console.log("Disconnected from SquaksChannel");
  },

  received(data) {
    // Called when data is broadcast to this channel
    console.log("New squak received:", data);

    const squakHtml = `
<li class="squak-item  m-3 px-1 py-1">
  <div class="row">
    <div class="col-sm-3 col-md-2 col-lg-1 squak-avatar-col">
      <div class="squak-avatar">
        <img src="https://robohash.org/${data.username}?size=60x60" class="img-fluid" />
      </div>
    </div>
    <div class="col-sm-9 col-md-10 col-lg-11">
      <div class="row ms-1 squak-username">
        ${data.username}
      </div>
      <div class="row ms-4 squak-body">
        ${data.body}
      </div>
      <div class="row">
        <div class="squak-date text-end">
          ${data.created_at}
        </div>
      </div>
    </div>
  </div>
</li>
`;

    const squakList = document.querySelector('#squaks-list');

    if (squakList) {
      console.log('updating squak list')
      squakList.insertAdjacentHTML('afterbegin', squakHtml);
    }
    const squakEditor = document.querySelector('#squak-editor');
    if (squakEditor) {
      squakEditor.innerHTML = '';
    }
  },

});
