
import express from "express";
import auth from "./basic";
const app = express();

app.use(auth);

app.get('/', (_req, res) => res.send('DONE'))

app.listen(8080, () => console.log("8080"));
