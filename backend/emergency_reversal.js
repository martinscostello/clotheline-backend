const mongoose = require('mongoose');
require('dotenv').config();
const Category = require('./models/Category');
const Service = require('./models/Service');

async function revert() {
    try {
        await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/clotheline');
        console.log("Connected to DB. Starting EMERGENCY REVERSAL...");

        // 1. DELETE any item with IDs starting with 698... (The incorrect clones)
        // Note: Using regex on _id is tricky with ObjectIds, but these are newly created.
        // Actually, I can just find them by searching for IDs > '698' if they are hex strings or just match the pattern.
        // A safer way: I'll find them first then delete.

        const svcsToDelete = await Service.find({ _id: { $gte: mongoose.Types.ObjectId.createFromHexString('698000000000000000000000') } });
        console.log(`Found ${svcsToDelete.length} incorrect Services to delete.`);
        for (let s of svcsToDelete) {
            await Service.findByIdAndDelete(s._id);
            console.log(`Deleted Service: ${s.name} (${s._id})`);
        }

        const catsToDelete = await Category.find({ _id: { $gte: mongoose.Types.ObjectId.createFromHexString('698000000000000000000000') } });
        console.log(`Found ${catsToDelete.length} incorrect Categories to delete.`);
        for (let c of catsToDelete) {
            await Category.findByIdAndDelete(c._id);
            console.log(`Deleted Category: ${c.name} (${c._id})`);
        }

        // 2. RESTORE items starting with 696... (The original data)
        const svcsToRestore = await Service.find({ _id: { $lt: mongoose.Types.ObjectId.createFromHexString('698000000000000000000000') } });
        console.log(`Found ${svcsToRestore.length} original Services to restore to Global.`);
        for (let s of svcsToRestore) {
            s.branchId = null;
            await s.save();
            console.log(`Restored Service: ${s.name} to Global.`);
        }

        const catsToRestore = await Category.find({ _id: { $lt: mongoose.Types.ObjectId.createFromHexString('698000000000000000000000') } });
        console.log(`Found ${catsToRestore.length} original Categories to restore to Global.`);
        for (let c of catsToRestore) {
            c.branchId = null;
            await c.save();
            console.log(`Restored Category: ${c.name} to Global.`);
        }

        console.log("REVERSAL COMPLETE! 🛡️🚨");
    } catch (err) {
        console.error("Reversal Error:", err);
    } finally {
        mongoose.connection.close();
    }
}

revert();
