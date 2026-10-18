import base64
import urllib.request
from contextlib import asynccontextmanager
from pathlib import Path

import cv2
import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

ROOT = Path(__file__).resolve().parent
MODEL_DIR = ROOT / "models"
DETECTOR_PATH = MODEL_DIR / "face_detection_yunet_2023mar.onnx"
RECOGNIZER_PATH = MODEL_DIR / "face_recognition_sface_2021dec.onnx"
MODELS = {
    DETECTOR_PATH: "https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx",
    RECOGNIZER_PATH: "https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx",
}
THRESHOLD = 0.55

detector = None
recognizer = None


def ensure_models() -> None:
    MODEL_DIR.mkdir(exist_ok=True)
    for path, url in MODELS.items():
        if path.exists() and path.stat().st_size > 1000:
            continue
        urllib.request.urlretrieve(url, path)


def load_models() -> bool:
    global detector, recognizer
    if not DETECTOR_PATH.exists() or not RECOGNIZER_PATH.exists():
        return False
    detector = cv2.FaceDetectorYN.create(str(DETECTOR_PATH), "", (320, 320), 0.6, 0.3, 5000)
    recognizer = cv2.FaceRecognizerSF.create(str(RECOGNIZER_PATH), "")
    return True


@asynccontextmanager
async def lifespan(_app: FastAPI):
    try:
        ensure_models()
        load_models()
    except Exception:
        # The API stays up so Laravel can report that models are unavailable.
        pass
    yield


app = FastAPI(title="Smart College Face Service", lifespan=lifespan)


class ImageIn(BaseModel):
    image: str


class Candidate(BaseModel):
    id: int
    embedding: list[float]


class MatchIn(BaseModel):
    image: str
    candidates: list[Candidate] = Field(default_factory=list)
    threshold: float | None = None


class SamplesIn(BaseModel):
    images: list[str] = Field(min_length=3, max_length=6)


class CompareIn(BaseModel):
    embedding: list[float]
    candidates: list[Candidate] = Field(default_factory=list)
    threshold: float | None = None


def decode_image(data: str):
    if "," in data:
        data = data.split(",", 1)[1]
    try:
        raw = base64.b64decode(data)
    except Exception as error:
        raise HTTPException(status_code=422, detail="Image data is not valid base64.") from error
    image = cv2.imdecode(np.frombuffer(raw, np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise HTTPException(status_code=422, detail="Could not read the image.")
    return image


def require_models() -> None:
    if recognizer is None and not load_models():
        raise HTTPException(status_code=503, detail="Face models are not installed yet.")


def prepare(image):
    height, width = image.shape[:2]
    longest = max(width, height)
    if longest > 800:
        scale = 800 / longest
        image = cv2.resize(image, (int(width * scale), int(height * scale)))
    return image


def analyze(image):
    require_models()
    image = prepare(image)
    height, width = image.shape[:2]
    detector.setInputSize((width, height))
    _count, faces = detector.detect(image)
    if faces is None or len(faces) == 0:
        raise HTTPException(status_code=422, detail="No face detected.")
    if len(faces) > 1:
        raise HTTPException(status_code=422, detail="Multiple faces detected. Only one person is allowed.")
    face = faces[0]
    box_w = float(face[2])
    box_h = float(face[3])
    if box_w < width * 0.18 or box_h < height * 0.22:
        raise HTTPException(status_code=422, detail="Move closer.")
    if box_w > width * 0.78:
        raise HTTPException(status_code=422, detail="Move slightly back.")
    center_x = float(face[0]) + box_w / 2
    center_y = float(face[1]) + box_h / 2
    oval_x = (center_x - width / 2) / (width * 0.24)
    oval_y = (center_y - height / 2) / (height * 0.34)
    if oval_x * oval_x + oval_y * oval_y > 1:
        raise HTTPException(status_code=422, detail="Position your face inside the oval.")
    if len(face) >= 11:
        eye_distance = max(abs(float(face[6]) - float(face[4])), 8.0)
        yaw = (float(face[8]) - (float(face[4]) + float(face[6])) / 2) / eye_distance
        pitch = (float(face[9]) - (float(face[5]) + float(face[7])) / 2) / eye_distance
        if abs(yaw) > 0.62 or pitch < 0.02 or pitch > 1.15:
            raise HTTPException(status_code=422, detail="Turn to face the camera. An extreme angle cannot be used.")
    aligned = recognizer.alignCrop(image, face)
    features = recognizer.feature(aligned).flatten().astype(float)
    nose = [float(face[8]), float(face[9])] if len(face) >= 10 else [center_x, center_y]
    return {"embedding": features.tolist(), "nose": nose, "width": width}


def best_match(vector, candidates, threshold):
    require_models()
    query = np.array(vector, dtype=np.float32).reshape(1, -1)
    ranked = []
    for candidate in candidates:
        stored = np.array(candidate.embedding, dtype=np.float32).reshape(1, -1)
        if stored.shape != query.shape or stored.size != 128:
            continue
        score = float(recognizer.match(query, stored, cv2.FaceRecognizerSF_FR_COSINE))
        ranked.append((score, candidate.id))
    ranked.sort(key=lambda item: item[0], reverse=True)
    requested = THRESHOLD if threshold is None else float(threshold)
    # A lower stored setting used to accept a different person as the only saved face.
    cutoff = max(requested, THRESHOLD)
    if not ranked or ranked[0][0] < cutoff:
        return {"matched": False, "score": None if not ranked else ranked[0][0], "threshold": cutoff}
    if len(ranked) > 1 and ranked[0][0] - ranked[1][0] < 0.08:
        return {"matched": False, "score": ranked[0][0], "threshold": cutoff, "reason": "ambiguous"}
    return {"matched": True, "id": ranked[0][1], "score": ranked[0][0], "threshold": cutoff}


@app.get("/health")
def health():
    ready = recognizer is not None or load_models()
    return {"ok": bool(ready), "models": bool(ready)}


@app.post("/embed")
def embed(body: ImageIn):
    found = analyze(decode_image(body.image))
    return {"embedding": found["embedding"], "nose": found["nose"]}


@app.post("/embed-samples")
def embed_samples(body: SamplesIn):
    samples = [analyze(decode_image(image)) for image in body.images]
    vectors = [np.array(sample["embedding"], dtype=np.float32) for sample in samples]
    query = vectors[0].reshape(1, -1)
    for vector in vectors[1:]:
        score = float(recognizer.match(query, vector.reshape(1, -1), cv2.FaceRecognizerSF_FR_COSINE))
        if score < 0.55:
            raise HTTPException(status_code=422, detail="The face changed during capture. Only one person is allowed.")
    noses = [sample["nose"] for sample in samples]
    shift = max(max(point[0] for point in noses) - min(point[0] for point in noses), max(point[1] for point in noses) - min(point[1] for point in noses))
    if shift < 6:
        raise HTTPException(status_code=422, detail="Turn your head slightly between captures. A still photograph cannot be registered.")
    mean = np.mean(np.stack(vectors), axis=0)
    mean = mean / max(float(np.linalg.norm(mean)), 1e-6)
    return {"embedding": mean.astype(float).tolist(), "samples": len(samples), "movement": True}


@app.post("/match")
def match(body: MatchIn):
    vector = analyze(decode_image(body.image))["embedding"]
    return best_match(vector, body.candidates, body.threshold)


@app.post("/compare")
def compare(body: CompareIn):
    return best_match(body.embedding, body.candidates, body.threshold)
