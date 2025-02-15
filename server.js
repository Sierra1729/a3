const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require("D:\andriod studio\a3\backend\sahayak-1f4e7-firebase-adminsdk-fbsvc-877a8f4716.json"); // Replace with actual path

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://sahayak-1f4e7-default-rtdb.firebaseio.com/" // Replace with your Firebase project ID
});

const db = admin.firestore();
const app = express();
const PORT = 8080;

app.use(cors());
app.use(express.json()); // Enable JSON parsing

// 🔹 API: Get Notifications from Firebase
app.get('/get-notifications', async (req, res) => {
    try {
        console.log("📡 Fetching notifications from Firebase...");
        const snapshot = await db.collection("notifications").orderBy("timestamp", "desc").get();

        let notifications = [];
        snapshot.forEach((doc) => {
            notifications.push({ id: doc.id, ...doc.data() });
        });

        console.log("✅ Notifications retrieved:", notifications);
        res.status(200).json({ success: true, data: notifications });
    } catch (error) {
        console.error("❌ Firebase Fetch Error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
});

// 🔹 Start the server
app.listen(PORT, () => {
    console.log(`🚀 Server running on http://localhost:${PORT}`);
});

