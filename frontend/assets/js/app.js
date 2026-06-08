// =============================================
// HostelHub - Main JavaScript File
// =============================================

// Auth Helper Functions
//Student Login Functions



function loginAdmin() {
    const username = document.getElementById('admin-username');
    const password = document.getElementById('admin-password');

    if (!username || !password) return;

    if (username.value.trim() !== "" && password.value.trim() !== "") {
        alert("✅ Admin Login successful!");
        localStorage.setItem("isAdmin", "true");
        localStorage.setItem("currentUser", "Admin");
        window.location.href = "dashboard.html";
    } else {
        alert("❌ Please enter admin credentials");
    }
}

function signup() {
    const name = document.getElementById('full-name');
    if (name && name.value.trim() !== "") {
        alert(`✅ Account created successfully for ${name.value}!`);
        window.location.href = "login.html";
    } else {
        alert("Please fill in your full name");
    }
}

function logout() {
    if (confirm("Are you sure you want to logout?")) {
        localStorage.clear();
        window.location.href = "index.html";
    }
}

// Transaction Manager (from previous)
class HostelTransaction {
    constructor() {
        this.transactions = JSON.parse(localStorage.getItem('transactions')) || [];
    }

    saveTransaction(type, details, status = "SUCCESS") {
        const transaction = {
            id: "TXN-" + Date.now().toString(36).toUpperCase(),
            timestamp: new Date().toISOString(),
            type: type,
            details: details,
            status: status,
            user: localStorage.getItem('currentUser') || "Guest"
        };
        
        this.transactions.unshift(transaction);
        localStorage.setItem('transactions', JSON.stringify(this.transactions));
        return transaction.id;
    }
}

const transactionManager = new HostelTransaction();
window.transactionManager = transactionManager;

// Auto-initialize when page loads
window.onload = function() {
    // Detect which page is loaded and run specific code
    const path = window.location.pathname;

    if (path.endsWith('index.html') || path === '/' || path.endsWith('/')) {
        initializeLandingPage();
    }
    
    // Add more page-specific initializations here later
};

// Make key functions globally available
window.loginAdmin = loginAdmin;
window.signup = signup;
window.logout = logout;
