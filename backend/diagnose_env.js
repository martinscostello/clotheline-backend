const path = require('path');
const fs = require('fs');

console.log("Current Directory:", process.cwd());
console.log("__dirname:", __dirname);

const envPath = path.resolve(__dirname, '.env');
console.log("Target .env Path:", envPath);

if (fs.existsSync(envPath)) {
    console.log("✅ .env file EXISTS at this path.");
    const content = fs.readFileSync(envPath, 'utf8');
    console.log("File content length:", content.length);
    console.log("First 50 chars:", content.substring(0, 50).replace(/\n/g, '\\n'));
} else {
    console.error("❌ .env file NOT FOUND at this path!");
}

// Try loading with dotenv
const result = require('dotenv').config({ path: envPath });

console.log("Dotenv parsed keys:", result.parsed ? Object.keys(result.parsed) : "NONE");
console.log("Error:", result.error);

console.log("EMAIL_USER Env Var:", process.env.EMAIL_USER);
