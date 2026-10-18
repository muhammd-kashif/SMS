from datetime import date, datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.models.attendance import Attendance
from app.models.student import Student


class AttendanceService:
    def __init__(self, db: Session):
        self._db = db

    def mark(
        self,
        person_type: str,
        person_id: int,
        at: datetime,
        status: str,
        source: str = "manual",
        confidence: Optional[float] = None,
        client_uuid: Optional[str] = None,
        overwrite: bool = True,
        notes: Optional[str] = None,
    ) -> dict:
        att_date = at.date()
        existing = (
            self._db.query(Attendance)
            .filter(
                Attendance.person_type == person_type,
                Attendance.person_id == person_id,
                Attendance.attendance_date == att_date,
            )
            .first()
        )

        if existing and not overwrite:
            return {"attendance": existing, "created": False}

        if existing:
            existing.status = status
            existing.check_in_time = at.time()
            existing.source = source
            existing.confidence = confidence
            existing.notes = notes
            self._db.commit()
            self._db.refresh(existing)
            return {"attendance": existing, "created": False}

        record = Attendance(
            person_type=person_type,
            person_id=person_id,
            attendance_date=att_date,
            check_in_time=at.time(),
            status=status,
            source=source,
            confidence=confidence,
            client_uuid=client_uuid,
            notes=notes,
        )
        self._db.add(record)
        self._db.commit()
        self._db.refresh(record)
        return {"attendance": record, "created": True}

    def close_day(
        self,
        day: date,
        class_id: Optional[int] = None,
        section_id: Optional[int] = None,
    ) -> int:
        """Mark all students without attendance for a day as absent."""
        query = self._db.query(Student).filter(Student.status == "active")
        if class_id:
            query = query.filter(Student.class_id == class_id)
        if section_id:
            query = query.filter(Student.section_id == section_id)
        students = query.all()

        existing_ids = set(
            r.person_id
            for r in self._db.query(Attendance)
            .filter(
                Attendance.person_type == "student",
                Attendance.attendance_date == day,
            )
            .all()
        )

        count = 0
        for student in students:
            if student.id not in existing_ids:
                self._db.add(
                    Attendance(
                        person_type="student",
                        person_id=student.id,
                        attendance_date=day,
                        status="absent",
                        source="auto",
                    )
                )
                count += 1
        self._db.commit()
        return count

    def summary_for_student(self, student: Student) -> dict:
        records = (
            self._db.query(Attendance)
            .filter(
                Attendance.person_type == "student",
                Attendance.person_id == student.id,
            )
            .all()
        )
        total = len(records)
        present = sum(1 for r in records if r.status == "present")
        absent = sum(1 for r in records if r.status == "absent")
        late = sum(1 for r in records if r.status == "late")
        leave = sum(1 for r in records if r.status == "leave")
        counted = present + absent + late
        return {
            "total": total,
            "present": present,
            "absent": absent,
            "late": late,
            "leave": leave,
            "percentage": round((present / counted) * 100, 1) if counted else 0,
        }
