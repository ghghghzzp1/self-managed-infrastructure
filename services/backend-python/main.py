from fastapi import FastAPI

app = FastAPI(title="Backend Python", version="0.0.1")


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "backend-python"
    }


# TODO: Phase 3+ - Add API routes here
