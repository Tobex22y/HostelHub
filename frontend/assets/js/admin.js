const adminIdentifier = document.getElementById('adminIdentifier');
const adminPassword = document.getElementById('adminPassword');
const adminLoginBtn = document.getElementById('adminLoginBtn');
const adminStatus = document.getElementById('adminStatus');
const adminAuth = document.getElementById('adminAuth');
const adminPanel = document.getElementById('adminPanel');
const adminName = document.getElementById('adminName');
const adminRole = document.getElementById('adminRole');
const adminLogoutBtn = document.getElementById('adminLogoutBtn');

function showAdminStatus(message, type = 'success') {
    adminStatus.textContent = message;
    adminStatus.className = `status ${type}`;
    adminStatus.classList.remove('hidden');
}

function hideAdminStatus() {
    adminStatus.classList.add('hidden');
}

adminLoginBtn.addEventListener('click', async () => {
    hideAdminStatus();
    const identifier = adminIdentifier.value.trim();
    const password = adminPassword.value;

    if (!identifier || !password) {
        showAdminStatus('Enter admin username/email and password.', 'error');
        return;
    }

    const response = await fetch('../api/admin_login.php', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ identifier, password })
    });

    const result = await response.json();
    if (!result.success) {
        showAdminStatus(result.message || 'Login failed.', 'error');
        return;
    }

    adminName.textContent = result.data.first_name + ' ' + result.data.last_name;
    adminRole.textContent = `Role: ${result.data.role}`;
    adminAuth.classList.add('hidden');
    adminPanel.classList.remove('hidden');
});

adminLogoutBtn.addEventListener('click', async () => {
    await fetch('../api/admin_logout.php', {
        method: 'POST',
        credentials: 'include'
    });
    adminPanel.classList.add('hidden');
    adminAuth.classList.remove('hidden');
    adminIdentifier.value = '';
    adminPassword.value = '';
    hideAdminStatus();
    showAdminStatus('Logged out successfully.', 'success');
});
