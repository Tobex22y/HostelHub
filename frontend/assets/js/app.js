// ==============================
// Student Dashboard Script (FINAL CLEAN VERSION)
// ==============================

const API = "http://localhost/HMS/backend/api";

// ==============================
// GLOBAL STATE
// ==============================

let currentStudentEmail = null;
let currentAllocation = null;

// ==============================
// INIT
// ==============================

document.addEventListener("DOMContentLoaded", () => {
  loadDashboard();
  loadRooms();
  loadAllocation();

  // 🔥 REAL-TIME AUTO REFRESH (every 5 seconds)
  setInterval(() => {
    loadAllocation();
  }, 5000);
});

// ==============================
// DASHBOARD INFO
// ==============================

async function loadDashboard() {
  try {
    const res = await fetch(`${API}/auth/dashboard.php`, {
      credentials: "include",
    });

    const data = await res.json();

    if (!data.success) {
      window.location.href = "login.html";
      return;
    }

    const student = data.student;
    currentStudentEmail = student.email;

    document.querySelector(".topbar h3").innerText =
      `Welcome, ${student.fullname} 👋`;

    document.getElementById("roomStatus").innerText = data.allocation
      ? "Allocated"
      : "Not Assigned";

    document.getElementById("paymentStatus").innerText =
      data.allocation?.status === "paid" ? "Paid" : "Pending";
  } catch (err) {
    console.error(err);
  }
}

// ==============================
// LOAD ROOMS
// ==============================

async function loadRooms() {
  try {
    const res = await fetch(`${API}/student/rooms.php`);
    const data = await res.json();

    const container = document.getElementById("roomsContainer");
    container.innerHTML = "";

    if (!data.rooms?.length) {
      container.innerHTML = "<p>No rooms available.</p>";
      return;
    }

    data.rooms.forEach((room) => {
      const div = document.createElement("div");
      div.className = "room-card";

      div.innerHTML = `
        <h3>Room ${room.room_number}</h3>
        <p>Type: ${room.room_type}</p>

        <div class="room-info">
          <span class="badge available">🛏 ${room.available} Available</span>
          <span class="badge occupied">🚫 ${room.occupied} Occupied</span>
        </div>

        <button class="action-btn"
          onclick="openRoom(${room.id}, '${room.room_number}')">
          View Beds
        </button>
      `;

      container.appendChild(div);
    });
  } catch (err) {
    console.error(err);
  }
}

// ==============================
// OPEN ROOM MODAL
// ==============================

async function openRoom(roomId, roomNumber) {
  const modal = document.getElementById("roomModal");
  const title = document.getElementById("modalTitle");
  const bedsBox = document.getElementById("modalBeds");

  title.innerText = `Room ${roomNumber}`;
  bedsBox.innerHTML = "Loading...";
  modal.style.display = "flex";

  try {
    const res = await fetch(`${API}/student/room_beds.php?room_id=${roomId}`);
    const data = await res.json();

    bedsBox.innerHTML = "";

    data.beds.forEach((bed) => {
      const div = document.createElement("div");
      div.className = "room-card";

      div.innerHTML = `
        <h3>Bed ${bed.bed_number}</h3>
        <p>${bed.is_occupied == 1 ? "🔴 Occupied" : "🟢 Available"}</p>
      `;

      if (!bed.is_occupied) {
        const btn = document.createElement("button");
        btn.className = "action-btn";
        btn.innerText = "Reserve Bed";

        btn.onclick = () => reserveBed(roomId, bed.id);

        div.appendChild(btn);
      }

      bedsBox.appendChild(div);
    });
  } catch (err) {
    console.error(err);
  }
}

// ==============================
// CLOSE MODAL
// ==============================

function closeModal() {
  document.getElementById("roomModal").style.display = "none";
}

window.onclick = function (e) {
  const modal = document.getElementById("roomModal");
  if (e.target === modal) closeModal();
};

// ==============================
// RESERVE BED
// ==============================

function reserveBed(roomId, bedId) {
  fetch(`${API}/student/reserve.php`, {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ room_id: roomId, bed_id: bedId }),
  })
    .then((res) => res.json())
    .then((data) => {
      if (data.success) {
        alert("Reservation successful!");

        closeModal();

        loadRooms();
        loadAllocation(); // 🔥 instant UI update
      } else {
        alert(data.message);
      }
    })
    .catch(console.error);
}

// ==============================
// LOAD ALLOCATION (REAL-TIME SAFE)
// ==============================

async function loadAllocation() {
  try {
    const res = await fetch(`${API}/student/allocation.php`, {
      credentials: "include",
    });

    const data = await res.json();

    const box = document.getElementById("allocationBox");
    if (!box) return;

    if (!data.success || !data.allocation) {
      currentAllocation = null;

      box.innerHTML = `
        <div class="empty-card">
          <h3>No Allocation Yet</h3>
          <p>You have not reserved a room.</p>
        </div>
      `;
      return;
    }

    currentAllocation = data.allocation;

    const alloc = data.allocation;

    box.innerHTML = `
      <div class="allocation-card">
        <h3>🎉 Your Allocation</h3>

        <div class="allocation-item">
          <span>Room</span>
          <strong>${alloc.room_number}</strong>
        </div>

        <div class="allocation-item">
          <span>Bed</span>
          <strong>${alloc.bed_number}</strong>
        </div>

        <div class="allocation-item">
          <span>Status</span>
          <strong>${alloc.status}</strong>
        </div>

        ${
          alloc.status === "approved"
            ? `<button class="action-btn pay-btn"
                onclick="payForAllocation(${alloc.id})">
                💳 Pay Now
              </button>`
            : `<div class="paid-badge">⏳ Waiting for admin approval</div>`
        }
      </div>
    `;
  } catch (err) {
    console.error(err);
  }
}

// ==============================
// PAYSTACK
// ==============================

function payWithPaystack(email, amount, allocationId) {
  const handler = PaystackPop.setup({
    key: "pk_test_ee4c2475b4ddbee902eb8a12801a4adc91b04340",
    email,
    amount: amount * 100,
    currency: "NGN",

    callback: function (response) {
      verifyPayment(response.reference, allocationId);
    },

    onClose: function () {
      alert("Payment cancelled");
    },
  });

  handler.openIframe();
}

// ==============================
// PAYMENT TRIGGER
// ==============================

function payForAllocation(allocationId) {
  if (!currentAllocation) return alert("No allocation found");

  if (currentAllocation.status !== "approved") {
    return alert("Wait for admin approval before payment");
  }

  payWithPaystack(currentStudentEmail, 50000, allocationId);
}

// ==============================
// VERIFY PAYMENT
// ==============================

async function verifyPayment(reference, allocationId) {
  const res = await fetch(`${API}/student/verify_payment.php`, {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ reference, allocation_id: allocationId }),
  });

  const data = await res.json();

  if (data.success) {
    alert("Payment successful!");

    // 🔥 instant UI refresh
    loadAllocation();

    // optional: open receipt
    window.open(`${API}/student/receipt.php?reference=${reference}`, "_blank");
  } else {
    alert(data.message);
  }
}

// ==============================
// LOGOUT
// ==============================

async function logout() {
  const res = await fetch(`${API}/auth/logout.php`, {
    method: "POST",
    credentials: "include",
  });

  const data = await res.json();

  if (data.success) {
    localStorage.clear();
    window.location.href = "login.html";
  }
}
