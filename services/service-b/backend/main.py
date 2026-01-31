from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os

app = FastAPI(title="Service B - Login", version="0.0.1")

# Mount static files if directory exists
static_path = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_path):
    app.mount("/assets", StaticFiles(directory=os.path.join(static_path, "assets")), name="assets")


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "service-b"
    }


@app.post("/api/login")
def login(username: str = "", password: str = ""):
    # TODO: Implement actual authentication
    return {
        "success": True,
        "message": "Login successful",
        "token": "placeholder_token"
    }


@app.get("/")
def serve_spa():
    """Serve the SPA index.html for all non-API routes"""
    index_path = os.path.join(static_path, "index.html")
    if os.path.exists(index_path):
        return FileResponse(index_path)
    return {"message": "Service B - Login API"}


@app.get("/{full_path:path}")
def catch_all(full_path: str):
    """Catch-all route for SPA routing"""
    if full_path.startswith("api/") or full_path == "health":
        return {"error": "Not found"}

    index_path = os.path.join(static_path, "index.html")
    if os.path.exists(index_path):
        return FileResponse(index_path)
    return {"message": "Service B - Login API"}
