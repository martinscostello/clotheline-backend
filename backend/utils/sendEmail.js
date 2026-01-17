const nodemailer = require('nodemailer');

const sendEmail = async (options) => {
    // 1. Create Transporter
    // TIP: For development without real credentials, we can just log to console
    // But we'll set up the structure for Gmail/SMTP

    // If you want to use Gmail:
    // service: 'gmail', auth: { user: process.env.EMAIL_USER, pass: process.env.EMAIL_PASS }

    // For now, if no credentials, we just log it (Dev Mode)
    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
        console.log("---------------------------------------------------");
        console.log(`[Mock Email] To: ${options.email}`);
        console.log(`[Mock Email] Subject: ${options.subject}`);
        console.log(`[Mock Email] Body: ${options.message}`);
        console.log("---------------------------------------------------");
        return;
    }

    // Check if using Gmail host explicitly, or fallback to it
    const isGmail = process.env.EMAIL_HOST === 'smtp.gmail.com' || !process.env.EMAIL_HOST;

    const transporterOptions = !isGmail ? {
        host: process.env.EMAIL_HOST,
        port: process.env.EMAIL_PORT || 587,
        secure: process.env.EMAIL_PORT == 465,
        auth: {
            user: process.env.EMAIL_USER,
            pass: process.env.EMAIL_PASS
        },
        tls: {
            rejectUnauthorized: false
        },
        family: 4 // Force IPv4
    } : {
        service: 'gmail',
        auth: {
            user: process.env.EMAIL_USER,
            pass: process.env.EMAIL_PASS
        }
    };

    const transporter = nodemailer.createTransport(transporterOptions);

    // 2. Define Email Options
    // SendGrid requires a verified sender. 'apikey' is not an email.
    const senderEmail = process.env.EMAIL_USER === 'apikey' ? 'support@brimarcglobal.com' : process.env.EMAIL_USER;

    const mailOptions = {
        from: `"Clotheline Laundry" <${senderEmail}>`,
        to: options.email,
        subject: options.subject,
        text: options.message,
        // html: options.html // Optional
    };

    // 3. Send Email
    await transporter.sendMail(mailOptions);
};

module.exports = sendEmail;
