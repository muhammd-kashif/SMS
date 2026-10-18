import base64
import json
import os
import uuid
from datetime import datetime, time
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.attendance import Attendance, FaceTemplate
from app.models.student import Student
from app.models.teacher import Teacher
from app.models.user import User
from app.services.attendance_service import AttendanceService
from app.services.settings_store import SettingsStore

router = APIRouter(tags=["Face"])

FACE_SERVICE_URL = settings.FACE_SERVICE_URL.rstrip("/")


def _person_name(db: Session, person_type: str, person_id: int) -> str:
    if person_type == "student":
        s = db.query(Student).filter(Student.id == person_id).first()
        return s.user.name if s and s.user else f"Student #{person_id}"
    if person_type == "teacher":
        t = db.query(Teacher).filter(Teacher.id == person_id).first()
        return t.user.name if t and t.user else f"Teacher #{person_id}"
    return f"Person #{person_id}"


def _embedding_candidates(db: Session, exclude_owner: Optional[tuple] = None):
    rows = db.query(FaceTemplate).all()
    candidates = []
    for row in rows:
        if exclude_owner and (row.person_type, row.person_id) == exclude_owner:
            continue
        try:
            embedding = json.loads(row.embedding)
        except Exception:
            continue
        candidates.append({"id": row.id, "embedding": embedding})
    return rows, candidates


def _find_template(db: Session, template_id: int) -> FaceTemplate:
    return db.query(FaceTemplate).filter(FaceTemplate.id == template_id).first()


def _present_until_time(db: Session) -> time:
    raw = SettingsStore(db).get("present_until", "08:15")
    try:
        h, m = str(raw).split(":")
        return time(int(h), int(m))
    except Exception:
        return time(8, 15)


def _face_error_reason(detail) -> str:
    text = str(detail or "").lower()
    if "no face" in text:
        return "no_face"
    if "multiple" in text:
        return "multiple"
    if "closer" in text:
        return "too_far"
    if "back" in text:
        return "too_close"
    if "oval" in text or "position" in text:
        return "position"
    if "angle" in text or "turn" in text:
        return "angle"
    return "invalid"


async def _match_face(db: Session, image: str, candidates, threshold: float):
    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(
            f"{FACE_SERVICE_URL}/match",
            json={"image": image, "candidates": candidates, "threshold": threshold},
        )
    if response.status_code != 200:
        detail = None
        try:
            detail = response.json().get("detail")
        except Exception:
            detail = response.text
        return False, None, _face_error_reason(detail), detail
    data = response.json()
    if not data.get("matched"):
        return False, None, data.get("reason") or "not_recognized", data
    return True, data.get("id"), data.get("reason"), data


async def _embed_samples(images):
    async with httpx.AsyncClient(timeout=90.0) as client:
        response = await client.post(
            f"{FACE_SERVICE_URL}/embed-samples",
            json={"images": images},
        )
    if response.status_code != 200:
        detail = None
        try:
            detail = response.json().get("detail")
        except Exception:
            detail = response.text
        raise HTTPException(status_code=response.status_code, detail=detail or "Face registration failed.")
    return response.json()


@router.get("/face/health")
async def face_health():
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{FACE_SERVICE_URL}/health")
        return response.json()
    except Exception as exc:
        return {"ok": False, "models": False, "message": str(exc)}


@router.post("/face/look")
async def face_look(payload: dict):
    image = payload.get("image")
    if not image:
        return {"present": False, "reason": "no_face"}
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(f"{FACE_SERVICE_URL}/embed", json={"image": image})
        if response.status_code == 200:
            return {"present": True, "reason": "face"}
        detail = None
        try:
            detail = response.json().get("detail")
        except Exception:
            detail = response.text
        return {"present": False, "reason": _face_error_reason(detail)}
    except Exception as exc:
        return {"present": False, "reason": "invalid", "message": str(exc)}


async def _process_scan(payload: dict, db: Session):
    image = payload.get("image")
    if not image:
        return JSONResponse(status_code=422, content={"verified": False, "reason": "invalid", "message": "Missing image."})

    client_uuid = payload.get("client_uuid") or str(uuid.uuid4())
    captured_at = payload.get("captured_at")
    if captured_at:
        try:
            at = datetime.fromisoformat(captured_at.replace("Z", "+00:00")).replace(tzinfo=None)
        except Exception:
            at = datetime.now()
    else:
        at = datetime.now()

    person_type_filter = payload.get("person_type")
    expected_person_id = payload.get("expected_person_id")

    # candidate templates
    query = db.query(FaceTemplate)
    if person_type_filter:
        query = query.filter(FaceTemplate.person_type == person_type_filter)
    templates = query.all()

    if not templates:
        return JSONResponse(status_code=422, content={"verified": False, "reason": "not_registered", "message": "No faces registered."})

    candidates = []
    template_map = {}
    for row in templates:
        try:
            embedding = json.loads(row.embedding)
        except Exception:
            continue
        template_map[row.id] = row
        candidates.append({"id": row.id, "embedding": embedding})

    store = SettingsStore(db)
    try:
        threshold = float(store.get("face_match_threshold", 0.55))
    except Exception:
        threshold = 0.55
    threshold = max(0.55, threshold)

    matched, template_id, reason, data = await _match_face(db, image, candidates, threshold)
    if not matched:
        rr = reason if reason in ("not_recognized", "ambiguous") else "not_recognized"
        return JSONResponse(status_code=422, content={"verified": False, "reason": rr, "message": data if not isinstance(data, dict) else data})

    template = template_map.get(template_id)
    if not template:
        template = _find_template(db, template_id)
    if not template:
        return JSONResponse(status_code=422, content={"verified": False, "reason": "not_recognized"})

    if expected_person_id is not None and template.person_id != int(expected_person_id):
        return JSONResponse(status_code=422, content={"verified": False, "reason": "mismatch", "message": "Face does not match the selected person."})
    if person_type_filter and template.person_type != person_type_filter:
        return JSONResponse(status_code=422, content={"verified": False, "reason": "mismatch"})

    person_type = template.person_type
    person_id = template.person_id

    # dedupe already by client_uuid
    existing_uuid = db.query(Attendance).filter(Attendance.client_uuid == client_uuid).first()
    already_marked = False
    if existing_uuid:
        record = existing_uuid
        already_marked = True
    else:
        existing_day = db.query(Attendance).filter(
            Attendance.person_type == person_type,
            Attendance.person_id == person_id,
            Attendance.attendance_date == at.date(),
        ).first()
        if existing_day:
            record = existing_day
            already_marked = True
        else:
            present_until = _present_until_time(db)
            status_value = "present" if at.time() <= present_until else "late"
            result = AttendanceService(db).mark(
                person_type=person_type,
                person_id=person_id,
                at=at,
                status=status_value,
                source="face",
                confidence=float(data.get("score")) if isinstance(data, dict) and data.get("score") is not None else None,
                client_uuid=client_uuid,
                overwrite=False,
            )
            record = result["attendance"]
            already_marked = not result.get("created", True)

    person_obj = None
    if person_type == "student":
        student = db.query(Student).filter(Student.id == person_id).first()
        person_obj = {
            "name": student.user.name if student and student.user else None,
            "student_code": student.student_code if student else None,
            "code": student.student_code if student else None,
            "check_in": record.check_in_time.strftime("%I:%M %p") if record.check_in_time else None,
            "status": record.status,
        }
    else:
        teacher = db.query(Teacher).filter(Teacher.id == person_id).first()
        person_obj = {
            "name": teacher.user.name if teacher and teacher.user else None,
            "code": teacher.employee_code if teacher else None,
            "student_code": None,
            "check_in": record.check_in_time.strftime("%I:%M %p") if record.check_in_time else None,
            "status": record.status,
        }

    return {
        "verified": True,
        "person_type": person_type,
        "person_id": person_id,
        "already_marked": already_marked,
        "person": person_obj,
    }


@router.post("/face/scan")
async def face_scan(
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return await _process_scan(payload, db)


@router.post("/face/register")
async def face_register(
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    person_type = payload.get("person_type")
    person_id = payload.get("person_id")
    images = payload.get("images") or []
    if person_type not in ("student", "teacher"):
        raise HTTPException(status_code=422, detail="Invalid person type.")
    try:
        person_id = int(person_id)
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid person id.")

    # permission: teachers can only register themselves; admins any
    if person_type == "teacher" and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only an administrator can register a teacher face.")
    if current_user.role not in ("admin", "teacher"):
        raise HTTPException(status_code=403, detail="Not allowed.")

    if len(images) < 3:
        raise HTTPException(status_code=422, detail="At least 3 face samples are required.")

    # verify person exists
    if person_type == "student":
        person = db.query(Student).filter(Student.id == person_id).first()
        if not person:
            raise HTTPException(status_code=404, detail="Student not found.")
    else:
        person = db.query(Teacher).filter(Teacher.id == person_id).first()
        if not person:
            raise HTTPException(status_code=404, detail="Teacher not found.")

    embedded = await _embed_samples(images)
    new_embedding = embedded["embedding"]

    # duplicate check against other people
    rows, candidates = _embedding_candidates(db, exclude_owner=(person_type, person_id))
    if candidates:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{FACE_SERVICE_URL}/compare",
                json={"embedding": new_embedding, "candidates": candidates, "threshold": 0.55},
            )
        if response.status_code == 200:
            data = response.json()
            if data.get("matched"):
                other_template = _find_template(db, data.get("id"))
                if other_template:
                    other_name = _person_name(db, other_template.person_type, other_template.person_id)
                    raise HTTPException(status_code=409, detail=f"This face already belongs to {other_name}.")

    # save preview image from first sample
    preview_path = None
    try:
        raw = images[0]
        if "," in raw:
            raw = raw.split(",", 1)[1]
        binary = base64.b64decode(raw)
        preview_path = f"photos/face_{person_type}_{person_id}.jpg"
        storage = os.path.join(settings.STORAGE_PATH, preview_path)
        os.makedirs(os.path.dirname(storage), exist_ok=True)
        with open(storage, "wb") as f:
            f.write(binary)
    except Exception:
        preview_path = None

    # upsert template
    existing = db.query(FaceTemplate).filter(
        FaceTemplate.person_type == person_type,
        FaceTemplate.person_id == person_id,
    ).first()
    if existing:
        existing.embedding = json.dumps(new_embedding)
        existing.preview_path = preview_path or existing.preview_path
        existing.registered_by = current_user.id
        db.commit()
        db.refresh(existing)
    else:
        template = FaceTemplate(
            person_type=person_type,
            person_id=person_id,
            embedding=json.dumps(new_embedding),
            preview_path=preview_path,
            registered_by=current_user.id,
        )
        db.add(template)
        db.commit()

    return {"message": "Face registered successfully.", "preview_path": preview_path}


@router.post("/face/sync")
async def face_sync(
    payload: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    items = payload.get("items") or []
    processed = 0
    failed = []
    for item in items:
        try:
            scan_payload = {
                "image": item.get("image"),
                "client_uuid": item.get("client_uuid") or str(uuid.uuid4()),
                "captured_at": item.get("captured_at") or item.get("time"),
                "person_type": item.get("person_type"),
                "expected_person_id": item.get("expected_person_id") or item.get("person_id"),
            }
            result = await _process_scan(scan_payload, db)
            if isinstance(result, dict) and result.get("verified"):
                processed += 1
            else:
                failed.append(str(result))
        except Exception as exc:
            failed.append(str(exc))
    return {"message": "Sync complete.", "processed": processed, "failed": failed}
