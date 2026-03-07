const API_BASE = 'https://clotheline-api.onrender.com/api'; // Primary API (Render)
const BRANCHES = {
    'benin': '696a84765d0f23566dbc6e5d',
    'abuja': '696a84765d0f23566dbc6e61'
};

async function init() {
    const urlParams = new URLSearchParams(window.location.search);
    const pathParts = window.location.pathname.split('/').filter(p => p);
    let pathBranch = pathParts[pathParts.length - 1];

    // If serving from a physical directory (e.g. /pricelist/abuja/index.html)
    if (pathBranch === 'index.html') {
        pathBranch = pathParts[pathParts.length - 2];
    }

    // Check if the last path segment is 'pricelist' (meaning no branch was provided in path)
    let branchKey = urlParams.get('branch');
    if (!branchKey && pathBranch && pathBranch !== 'pricelist' && pathBranch !== 'pricelist-app.html') {
        branchKey = pathBranch;
    }
    branchKey = branchKey || 'benin';

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

        if (service.name.toLowerCase().includes('home and cleaning')) {
            html += `
                <div class="tc-section">
                    <details>
                        <summary>Terms and condition</summary>
                        <div class="tc-content" style="text-align: left;">
Home & Office Cleaning – Terms & Conditions

By accessing and booking Home & Office Cleaning services through this platform, you agree to the following Terms & Conditions.

⸻

 1. Service Booking & Confirmation
All cleaning services must be booked at least 24 hours in advance.
A booking is considered confirmed only after acknowledgment and scheduling confirmation within the platform.
Services may be rescheduled where necessary due to operational, safety, or unforeseen circumstances.

⸻

 2. Scope of Services
Cleaning services may include, but are not limited to:
• Home deep cleaning
• Office cleaning
• Post-construction cleaning
• Move-in / Move-out cleaning
• Specialized surface treatment

Any services outside the agreed scope must be approved in advance and may attract additional charges.

⸻

 3. Pricing & Inspection
Service pricing is determined based on:
• Property size
• Level of dirt or staining
• Type of cleaning required
• Special treatments or additional requests

Certain jobs may require a mandatory inspection before final pricing is confirmed.
Where inspection is required, an inspection fee may apply. This fee will be communicated before scheduling and must be paid prior to inspection.
Final pricing will be confirmed after inspection where applicable.

⸻

 4. Payment Terms
Unless otherwise agreed:
• Full payment is required upon completion of service.
• For large-scale or corporate jobs, a deposit (up to 70%) may be required before commencement.
• Outstanding balances must be cleared immediately after service completion.

Future service requests may be restricted in cases of unpaid balances.

⸻

 5. Cancellation Policy
To ensure fairness and operational efficiency:
• Cancellation more than 48 hours before service date: No cancellation fee.
• Cancellation between 24–48 hours before service date: 25% of total service cost.
• Cancellation less than 24 hours before service date: 50% of total service cost.
• Cancellation after arrival of cleaning team or after service has commenced: 70% of total service cost.

Cancellation fees cover manpower allocation, logistics, and reserved scheduling time.
All cancellations must be made through official communication channels within the platform.

⸻

 6. Refund Policy
Due to the nature of cleaning services:
• Refunds are not automatically granted once service has commenced.
• Any dissatisfaction must be reported within 24 hours of service completion.
• Verified service gaps may be rectified where applicable.

Once a service has been completed and approved on-site, refunds will not be issued.

⸻

 7. Client Responsibilities
Clients are responsible for providing:
• Access to water and electricity
• Safe working conditions
• Unrestricted access to service areas
• Removal or secure storage of valuables prior to service

The service provider shall not be held responsible for:
• Delays caused by denied or restricted access
• Loss or damage to items not disclosed or secured prior to service

⸻

 8. Damages & Liability
Any pre-existing damage must be disclosed before service begins.

While all items are handled with care, liability does not extend to:
• Pre-existing damage
• Normal wear and tear
• Poorly installed fixtures
• Undisclosed fragile or defective items

In the event of verified service-related damage, resolution will be handled at management’s discretion.

⸻

 9. Health & Safety
The property must be free from hazardous conditions.
Aggressive or unsecured pets must be properly restrained during service.
Service may be suspended if working conditions are deemed unsafe.

⸻

10. Staff Conduct
Service personnel are trained professionals and are not permitted to:
• Perform personal errands
• Accept tasks outside the agreed service scope
• Negotiate pricing directly

All service adjustments must be handled through official platform channels.

⸻

11. Amendments
Policies and procedures may be updated where necessary. The most current version will always be reflected within the platform.

⸻

12. Acceptance of Terms
By proceeding with a booking, you confirm that you have read, understood, and agreed to these Terms & Conditions.
                        </div>
                    </details>
                    <div class="tc-notice">
                        Notice: Post construction service is determined after inspection
                    </div>
                </div>
            `;
        }

        html += `
                <div class="last-updated">Last Updated: ${updatedDate}</div>
            </div>
        `;
    });

    container.innerHTML = html;
}

init();
