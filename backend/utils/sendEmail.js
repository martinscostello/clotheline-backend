const sgMail = require('@sendgrid/mail');

const sendEmail = async (options) => {
    // 1. Check for API Key
    if (!process.env.EMAIL_PASS || !process.env.EMAIL_PASS.startsWith('SG.')) {
        console.log("---------------------------------------------------");
        console.log(`[Mock Email] To: ${options.email}`);
        console.log(`[Mock Email] Subject: ${options.subject}`);
        console.log(`[Mock Email] Body: ${options.message}`);
        console.log(`[Mock Email] WARNING: Real email disabled. EMAIL_PASS must start with 'SG.'`);
        console.log("---------------------------------------------------");
        return;
    }

    // 2. Configure SendGrid
    // We reuse EMAIL_PASS for the API Key as per previous env config
    sgMail.setApiKey(process.env.EMAIL_PASS);

    // 3. Define Email Options
    // SendGrid requires a strictly verified sender identity.
    const senderEmail = 'support@brimarcglobal.com';

    const msg = {
        to: options.email,
        from: {
            email: senderEmail,
            name: "Clotheline Laundry"
        },
        subject: options.subject,
        text: options.message,
        // html: options.html // Optional
    };

    // 4. Send Email via HTTP API
    try {
        await sgMail.send(msg);
        console.log(`[SendGrid] Email sent to ${options.email}`);
    } catch (error) {
        console.error('[SendGrid] Error sending email:', error);
        if (error.response) {
            console.error(error.response.body);
        }
        throw new Error('Email sending failed via SendGrid API');
    }
};

module.exports = sendEmail;
