import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.routers import (
    academics,
    attendance,
    auth,
    face,
    dashboard,
    exams,
    fees,
    leaves,
    notifications,
    portal,
    reports,
    settings as settings_router,
    structure,
    students,
    teachers,
    users,
)

app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    debug=settings.APP_DEBUG,
)

# Enable CORS for frontend and mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ensure storage directories exist
os.makedirs(settings.STORAGE_PATH, exist_ok=True)
os.makedirs(os.path.join(settings.STORAGE_PATH, "photos"), exist_ok=True)
os.makedirs(os.path.join(settings.STORAGE_PATH, "documents"), exist_ok=True)
os.makedirs(os.path.join(settings.STORAGE_PATH, "logos"), exist_ok=True)

# Static file serving for uploads/photos/branding
app.mount("/storage", StaticFiles(directory=settings.STORAGE_PATH), name="storage")

# Include all API routers with /api prefix
app.include_router(auth.router, prefix="/api")
app.include_router(face.router, prefix="/api")
app.include_router(dashboard.router, prefix="/api")
app.include_router(students.router, prefix="/api")
app.include_router(teachers.router, prefix="/api")
app.include_router(users.router, prefix="/api")
app.include_router(academics.router, prefix="/api")
app.include_router(attendance.router, prefix="/api")
app.include_router(exams.router, prefix="/api")
app.include_router(fees.router, prefix="/api")
app.include_router(leaves.router, prefix="/api")
app.include_router(notifications.router, prefix="/api")
app.include_router(portal.router, prefix="/api")
app.include_router(reports.router, prefix="/api")
app.include_router(settings_router.router, prefix="/api")
app.include_router(structure.router, prefix="/api")


@app.get("/")
def root():
    return {
        "app": settings.APP_NAME,
        "status": "online",
        "docs": "/docs",
    }
