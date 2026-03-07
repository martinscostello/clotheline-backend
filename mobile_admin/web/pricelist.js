const API_BASE = 'https://clotheline-backend.vercel.app/api'; // Primary API
const BRANCHES = {
    'benin': '67ca9f977fc24b898be25330', // I'll need to confirm these IDs from the DB if possible, or fetch by name
    'abuja': '67ca9f977fc24b898be25331'
};

async function init() {
    const urlParams = new URLSearchParams(window.location.search);
    const branchKey = urlParams.get('branch') || 'benin';

    // Set branch name in UI
    const branchNameEl = document.getElementById('branch-name');
    branchNameEl.textContent = branchKey.charAt(0).toUpperCase() + branchKey.slice(1) + " Branch";

    const contentEl = document.getElementById('main-content');

    try {
        // [FIX] Try to fetch branch ID first if needed, or if we have it use it
        // For now, I'll attempt to fetch all branches to find the one matching the name
        const branchesResp = await fetch(`${API_BASE}/branches`);
        const branches = await branchesResp.json();
        const branch = branches.find(b =>
            b.name.toLowerCase().includes(branchKey.toLowerCase()) ||
            branchKey.toLowerCase().includes(b.name.toLowerCase().trim().split(' ')[0])
        );

        if (!branch) {
            throw new Error(`Branch ${branchKey} not found`);
        }

        const response = await fetch(`${API_BASE}/services/pricelist/${branch._id}`);
        if (!response.ok) throw new Error('Failed to fetch prices');

        const services = await response.json();
        renderPriceList(services, contentEl);

    } catch (err) {
        console.error(err);
        contentEl.innerHTML = `
            <div class="error-msg">
                <p>Unable to load price list at this time.</p>
                <p style="font-size: 12px; margin-top: 10px;">${err.message}</p>
            </div>
        `;
    }
}

function renderPriceList(services, container) {
    if (!services || services.length === 0) {
        container.innerHTML = '<p class="subtitle" style="text-align:center">No services available for this branch.</p>';
        return;
    }

    let html = '';
    services.forEach(service => {
        html += `
            <div class="category-section">
                <div class="category-header">
                    <span class="category-name">${service.name}</span>
                </div>
        `;

        service.items.forEach(item => {
            html += `
                <div class="service-card">
                    <div class="service-info">
                        <div class="service-name">${item.name}</div>
                        ${item.description ? `<div class="service-desc">${item.description}</div>` : ''}
                    </div>
                    <div class="service-price">₦${item.price.toLocaleString()}</div>
                </div>
            `;
        });

        const updatedDate = new Date(service.lastUpdated).toLocaleDateString('en-GB', {
            day: 'numeric', month: 'short', year: 'numeric'
        });

        html += `
                <div class="last-updated">Last Updated: ${updatedDate}</div>
            </div>
        `;
    });

    container.innerHTML = html;
}

init();
