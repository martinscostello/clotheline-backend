const sendEmail = require('../utils/sendEmail');
require('dotenv').config({ path: '../.env' });

const test = async () => {
    try {
        if (!process.env.EMAIL_USER) {
            console.error("Error: EMAIL_USER not found in .env");
            return;
        }

        console.log(`Attempting to send test email through ${process.env.EMAIL_HOST || 'Gmail'}...`);
        console.log(`User: ${process.env.EMAIL_USER}`);

        await sendEmail({
            email: process.env.EMAIL_USER, // Send to self
            subject: 'Clotheline SMTP Test',
            message: 'This is a test email to verify your SMTP settings are working correctly.'
        });

        console.log("✅ Test email sent successfully!");
    } catch (err) {
        console.error("❌ Email sending failed:", err);
    }
};

test();
