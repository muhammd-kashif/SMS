from sqlalchemy.orm import Session

from app.models.misc import AuditLog
from app.models.user import User


class AuditLogger:
    def __init__(self, db: Session):
        self._db = db

    def write(self, user: User, action: str, module: str, record_label: str = None) -> None:
        log = AuditLog(
            user_id=user.id if user else None,
            action=action,
            module=module,
            record_label=record_label,
        )
        self._db.add(log)
        self._db.commit()
