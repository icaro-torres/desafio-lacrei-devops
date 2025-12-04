const express = require('express');
const app = express();
const port = process.env.PORT || 3000;
const cors = require('cors');

app.use(cors());

app.use((req, res, next) => {
    const log = {
        timestamp: new Date().toISOString(),
        method: req.method,
        url: req.url,
        ip: req.ip,
        userAgent: req.get('User-Agent')
    };
    console.log(JSON.stringify(log));
    next();
});

app.get('/status', (req, res) => {
    res.json({
        app: "Lacrei Saúde Teste DevOps",
        status: "operational",
        environment: process.env.NODE_ENV || "development",
        version: "1.0.0",
        uptime: process.uptime()
    });
});

app.post('/api/asaas/payment-split', (req, res) => {
    res.status(200).json({
        provider: "Asaas",
        transactionId: "pay_" + Math.random().toString(36).substr(2, 9),
        status: "PENDING",
        split: [
            { walletId: "wallet_lacrei", percentual: 20 },
            { walletId: "wallet_prof", percentual: 80 }
        ],
        message: "Cobrança com split criada com sucesso (MOCK)"
    });
});

app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});