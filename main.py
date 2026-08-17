from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="ChipPilot Backend")


@app.get("/")
def home():
    return {
        "message": "ChipPilot backend is running!"
    }


class EvaluationRequest(BaseModel):
    rtl_code: str


@app.post("/evaluate")
def evaluate(request: EvaluationRequest):
    return {
        "status": "received",
        "rtl_code": request.rtl_code
    }