from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import subprocess
import json
import os
import uuid

app = FastAPI(title="ChipPilot Backend")


BASE_DIR = os.path.dirname(os.path.abspath(__file__))


class EvaluationRequest(BaseModel):
    rtl_code: str
    top_module: str


@app.get("/")
def home():
    return {
        "message": "ChipPilot backend is running!"
    }


@app.post("/evaluate")
def evaluate(request: EvaluationRequest):

    design_id = str(uuid.uuid4())[:8]

    rtl_dir = os.path.join(BASE_DIR, "rtl")
    reports_dir = os.path.join(BASE_DIR, "reports")
    evaluator = os.path.join(BASE_DIR, "scripts", "evaluate_design.sh")

    rtl_file = os.path.join(
        rtl_dir,
        f"api_{design_id}.v"
    )

    os.makedirs(rtl_dir, exist_ok=True)
    os.makedirs(reports_dir, exist_ok=True)

    try:
        # Save submitted RTL
        with open(rtl_file, "w") as f:
            f.write(request.rtl_code)

        # Convert Windows-mounted path to WSL path if necessary
        def wsl_path(path):
            path = os.path.abspath(path)

            if path.startswith("/mnt/"):
                return path

            if len(path) >= 2 and path[1] == ":":
                drive = path[0].lower()
                rest = path[2:].replace("\\", "/")
                return f"/mnt/{drive}{rest}"

            return path

        evaluator_wsl = wsl_path(evaluator)
        rtl_file_wsl = wsl_path(rtl_file)
        base_dir_wsl = wsl_path(BASE_DIR)

        # Run ChipPilot EDA evaluator
        result = subprocess.run(
            [
                "/bin/bash",
                evaluator_wsl,
                rtl_file_wsl,
                request.top_module
            ],
            cwd=base_dir_wsl,
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            raise HTTPException(
                status_code=500,
                detail={
                    "message": "EDA evaluation failed",
                    "error": result.stderr,
                    "output": result.stdout
                }
            )

        # Read generated PPA JSON
        ppa_file = os.path.join(
            reports_dir,
            f"{request.top_module}_ppa.json"
        )

        if not os.path.exists(ppa_file):
            raise HTTPException(
                status_code=500,
                detail={
                    "message": "EDA evaluation completed but PPA JSON was not generated.",
                    "expected_file": ppa_file,
                    "output": result.stdout
                }
            )

        with open(ppa_file, "r") as f:
            ppa = json.load(f)

        return {
            "status": "success",
            "design_id": design_id,
            "evaluation": ppa
        }

    except HTTPException:
        raise

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )