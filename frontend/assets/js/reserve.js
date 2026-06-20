let selectedRoom = null;

const roomsDiv = document.getElementById("rooms");
const bedsDiv = document.getElementById("beds");
const msg = document.getElementById("msg");

// 1. Load rooms
async function loadRooms() {
  const res = await fetch("http://localhost/HMS/backend/api/student/rooms.php");
  const data = await res.json();

  roomsDiv.innerHTML = "";

  data.rooms.forEach((room) => {
    const div = document.createElement("div");
    div.className = "card";
    div.innerHTML = `
      <h3>${room.room_number}</h3>
      <p>Type: ${room.room_type}</p>
      <p>Available: ${room.available}</p>
    `;

    div.onclick = () => loadBeds(room.id);

    roomsDiv.appendChild(div);
  });
}

// 2. Load beds for room
async function loadBeds(roomId) {
  selectedRoom = roomId;

  const res = await fetch(
    `http://localhost/HMS/backend/api/student/room_beds.php?room_id=${roomId}`,
  );

  const data = await res.json();

  bedsDiv.innerHTML = "";

  data.beds.forEach((bed) => {
    const div = document.createElement("div");
    div.className = `card ${bed.is_occupied == 1 ? "occupied" : "available"}`;

    div.innerHTML = `
      <h3>Bed ${bed.bed_number}</h3>
      <p>${bed.is_occupied == 1 ? "Occupied" : "Available"}</p>
    `;

    if (bed.is_occupied == 0) {
      const btn = document.createElement("button");
      btn.innerText = "Reserve";

      btn.onclick = () => reserveBed(roomId, bed.id);

      div.appendChild(btn);
    }

    bedsDiv.appendChild(div);
  });
}

// 3. Reserve bed
async function reserveBed(roomId, bedId) {
  msg.innerText = "Reserving...";

  const res = await fetch(
    "http://localhost/HMS/backend/api/student/reserve_bed.php",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        room_id: roomId,
        bed_id: bedId,
      }),
    },
  );

  const data = await res.json();

  if (data.success) {
    msg.innerText = "✅ Reservation successful! Proceed to payment.";
    loadBeds(roomId); // refresh UI
  } else {
    msg.innerText = "❌ " + data.message;
  }
}

loadRooms();
