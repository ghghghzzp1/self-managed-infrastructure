from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os

app = FastAPI(title="Service B", version="0.0.1")

# Static files directory
static_path = os.path.join(os.path.dirname(__file__), "static")


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "service-b"
    }


@app.get("/")
def serve_index():
    """Serve index.html"""
    index_path = os.path.join(static_path, "index.html")
    if os.path.exists(index_path):
        return FileResponse(index_path)
    return {"message": "Service B API"}


# TODO: Add your API endpoints here
