from fastapi import FastAPI

app = FastAPI(title="Service B", version="0.0.1")


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "service-b-backend"
    }


@app.get("/")
def root():
    return {"message": "Service B API", "version": "0.0.1"}


# TODO: Add your API endpoints here
