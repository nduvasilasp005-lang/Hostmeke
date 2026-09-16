require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const app = express();

// Allow your frontend's origin — tighten this in production
app.use(cors({ origin: '*' }));
app.use(express.json());

// Routes
app.use('/api/mpesa', require('./routes/mpesa'));

// Health check
app.get('/', (req, res) => res.json({ status: 'Host Me Ke API running ✅' }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`✅ Server running on http://localhost:${PORT}`));
