async function loadStats() {
  try {
    const res = await fetch(
      "http://localhost/HMS/backend/api/admin/stats.php",
      {
        credentials: "include",
      },
    );

    const data = await res.json();

    console.log("STATS DATA:", data);
    console.log("🔥 loadStats running");

    console.log("totalRooms element:", document.getElementById("totalRooms"));
    console.log("totalBeds element:", document.getElementById("totalBeds"));

    if (!data.success) {
      console.warn("Not authorized or failed stats fetch");
      return;
    }

    document.getElementById("totalRooms").innerText = data.total_rooms;
    document.getElementById("totalBeds").innerText = data.total_beds;
    document.getElementById("occupiedBeds").innerText = data.occupied_beds;
    document.getElementById("availableBeds").innerText = data.available_beds;
  } catch (err) {
    console.error("Stats error:", err);
  }
}

async function createRoom() {
  const room_number = document.getElementById("roomNumber").value;
  const room_type = document.getElementById("roomType").value;
  const capacity = document.getElementById("capacity").value;
  const price = document.getElementById("price").value;

  try {
    const res = await fetch(
      "http://localhost/HMS/backend/api/admin/rooms.php",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          room_number,
          room_type,
          capacity,
          price,
        }),
      },
    );

    const data = await res.json();

    if (data.success) {
      alert("Room created successfully!");
      location.reload();
    } else {
      alert(data.message);
    }
  } catch (err) {
    console.error(err);
    alert("Error creating room");
  }
}

async function loadRequests() {
  try {
    const res = await fetch(
      "http://localhost/HMS/backend/api/admin/get_requests.php",
    );
    const data = await res.json();

    const box = document.getElementById("requests");
    box.innerHTML = "";

    if (!data.requests || data.requests.length === 0) {
      box.innerHTML = `
        <div class="empty-state">
          <h3>No Pending Requests</h3>
          <p>All allocations are up to date.</p>
        </div>
      `;
      return;
    }

    data.requests.forEach((req) => {
      const div = document.createElement("div");

      div.className = "request-card";

      div.innerHTML = `
        <div class="request-header">
          <h3>${req.fullname}</h3>
          <span class="badge pending">Pending</span>
        </div>

        <div class="request-body">
          <p><strong>Room:</strong> ${req.room_number}</p>
          <p><strong>Bed:</strong> ${req.bed_number}</p>
          <p><strong>Email:</strong> ${req.email}</p>
        </div>

        <div class="request-actions">
          <button class="approve-btn" onclick="approve(${req.id})">
            ✅ Approve
          </button>

          <button class="reject-btn" onclick="reject(${req.id})">
            ❌ Reject
          </button>
        </div>
      `;

      box.appendChild(div);
    });
  } catch (err) {
    console.error("Load requests error:", err);
  }
}

document.addEventListener("DOMContentLoaded", () => {
  loadStats();
  loadRequests();

  // auto refresh every 5 seconds
  setInterval(() => {
    loadRequests();
    loadStats();
  }, 5000);
});

async function approve(id) {
  try {
    const res = await fetch(
      "http://localhost/HMS/backend/api/admin/approve_allocation.php",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ allocation_id: id }),
      },
    );

    const data = await res.json();

    if (data.success) {
      alert("Approved successfully");
      loadRequests();
      loadStats();
    } else {
      alert(data.message);
    }
  } catch (err) {
    console.error(err);
  }
}

async function reject(id) {
  try {
    const res = await fetch(
      "http://localhost/HMS/backend/api/admin/reject_allocation.php",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ allocation_id: id }),
      },
    );

    const data = await res.json();

    if (data.success) {
      alert("Rejected successfully");
      loadRequests();
      loadStats();
    } else {
      alert(data.message);
    }
  } catch (err) {
    console.error(err);
  }
}

async function resetDB() {
  if (!confirm("Are you sure? This will delete ALL data.")) return;

  const res = await fetch(
    "http://localhost/HMS/backend/api/admin/reset_database.php",
    {
      method: "POST",
      credentials: "include",
    },
  );

  const data = await res.json();

  if (data.success) {
    alert("System reset successful!");
    location.reload();
  } else {
    alert(data.message);
  }
}

document.addEventListener("DOMContentLoaded", () => {
  loadStats();
});
